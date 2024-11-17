# frozen_string_literal: true

require 'roda'
require 'slim'
require 'rack'

module MealDecoder
  # Web App
  class App < Roda
    plugin :environments
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/assets'
    plugin :static, ['/assets']
    plugin :flash
    plugin :all_verbs
    plugin :request_headers
    plugin :common_logger, $stderr
    plugin :halt

    use Rack::MethodOverride
    use Rack::Session::Cookie,
        secret: config.SESSION_SECRET,
        key: 'meal_decoder.session',
        expire_after: 2_592_000 # 30 days in seconds

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public

      # GET /
      routing.root do
        session[:searched_dishes] ||= []

        begin
          dishes = session[:searched_dishes].map do |dish_name|
            Services::FetchDish.new.call(dish_name).value_or(nil)
          end.compact

          session[:searched_dishes] = dishes.map(&:name)

          view 'home', locals: {
            title_suffix: 'Home',
            dishes: Views::DishesList.new(dishes)
          }
        rescue StandardError
          flash.now[:error] = 'Having trouble accessing the database'
          view 'home', locals: {
            title_suffix: 'Home',
            dishes: Views::DishesList.new([])
          }
        end
      end

      routing.on 'fetch_dish' do
        # POST /fetch_dish
        routing.post do
          form = Forms::NewDish.new.call(routing.params)
          if form.failure?
            flash[:error] = form.errors.messages.first.text
            routing.redirect '/'
          end

          result = Services::CreateDish.new.call(
            dish_name: form.to_h[:dish_name],
            session:
          )

          case result
          when Success
            flash[:success] = 'Successfully added new dish!'
            routing.redirect "/display_dish?name=#{CGI.escape(result.value!.name)}"
          when Failure
            flash[:error] = result.failure
            routing.redirect '/'
          end
        end
      end

      routing.on 'display_dish' do
        routing.get do
          dish_name = CGI.unescape(routing.params['name'].to_s)

          unless dish_name
            flash[:error] = 'Could not find that dish'
            routing.redirect '/'
          end

          result = Services::FetchDish.new.call(dish_name)

          case result
          when Success
            view 'dish', locals: {
              title_suffix: result.value!.name,
              dish: Views::Dish.new(result.value!)
            }
          when Failure
            flash[:error] = result.failure
            routing.redirect '/'
          end
        end
      end

      routing.on 'detect_text' do
        routing.post do
          upload_form = Forms::ImageFileUpload.new.call(routing.params)

          if upload_form.failure?
            flash[:error] = upload_form.errors.messages.first.text
            routing.redirect '/'
          end

          result = Services::DetectMenuText.new.call(upload_form.to_h[:image_file])

          case result
          when Success
            view 'display_text', locals: {
              title_suffix: 'Text Detection',
              text: Views::TextDetection.new(result.value!)
            }
          when Failure
            flash[:error] = result.failure
            routing.redirect '/'
          end
        end
      end

      routing.on 'dish', String do |encoded_dish_name|
        routing.delete do
          dish_name = CGI.unescape(encoded_dish_name)

          result = Services::RemoveDish.new.call(
            dish_name:,
            session:
          )

          case result
          when Success
            flash[:success] = 'Dish removed from history'
          when Failure
            flash[:error] = result.failure
          end

          routing.redirect '/'
        end
      end
    end
  end
end
