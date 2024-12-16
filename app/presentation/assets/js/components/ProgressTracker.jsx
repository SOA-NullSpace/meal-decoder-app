import { useState } from "react";

export default function MenuDecoder() {
  // States for dish form
  const [dishName, setDishName] = useState("");
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState("");
  const [progressInfo, setProgressInfo] = useState(null);

  // States for detected text
  const [detectedText, setDetectedText] = useState([]);
  const [showTextSelection, setShowTextSelection] = useState(false);

  // Progress tracking
  const [progress, setProgress] = useState(0);
  const [progressMessage, setProgressMessage] = useState("");

  // Handle direct dish name submission
  const handleDishSubmit = async (e) => {
    e.preventDefault();
    if (!dishName.trim()) return;

    setIsProcessing(true);
    setError("");

    try {
      const response = await fetch("/api/v1/dishes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ dish_name: dishName }),
      });

      const result = await response.json();

      if (response.ok) {
        if (result.status === "processing") {
          setupProgressTracking(result.progress);
        } else {
          window.location.href = `/display_dish?name=${encodeURIComponent(
            dishName
          )}`;
        }
      } else {
        setError(result.message || "Failed to process dish");
        setIsProcessing(false);
      }
    } catch (err) {
      setError("Error submitting dish");
      setIsProcessing(false);
    }
  };

  // Handle image upload
  const handleImageUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const formData = new FormData();
    formData.append("image_file", file);

    setIsProcessing(true);
    setError("");

    try {
      const response = await fetch("/api/v1/detect_text", {
        method: "POST",
        body: formData,
      });

      const result = await response.json();

      if (response.ok && result.status === "success") {
        setDetectedText(result.data);
        setShowTextSelection(true);
      } else {
        setError(result.message || "Failed to process image");
      }
    } catch (err) {
      setError("Error uploading image");
    } finally {
      setIsProcessing(false);
    }
  };

  // Setup WebSocket progress tracking
  const setupProgressTracking = (progressInfo) => {
    if (!progressInfo?.channel || !progressInfo?.endpoint) return;

    const wsUrl = progressInfo.endpoint.replace("http", "ws");
    const socket = new WebSocket(wsUrl);

    socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      setProgress(data.percentage || 0);
      setProgressMessage(data.message || "Processing...");

      if (data.percentage === 100) {
        setTimeout(() => {
          window.location.href = `/display_dish?name=${encodeURIComponent(
            dishName
          )}`;
        }, 500);
      }
    };

    socket.onerror = () => {
      setError("Lost connection to server");
      setIsProcessing(false);
    };
  };

  return (
    <div className="container mt-5">
      <header className="mb-4">
        <div className="d-flex justify-content-center">
          <h1 className="mb-0">Meal Decoder</h1>
        </div>
      </header>

      <section className="search-section mb-5">
        <div className="card">
          <div className="card-body">
            <h2 className="h4 mb-4">Decode Dish Name</h2>
            <form onSubmit={handleDishSubmit}>
              <div className="form-group">
                <label className="font-weight-bold" htmlFor="dish_name">
                  Enter the dish name:
                </label>
                <input
                  type="text"
                  id="dish_name"
                  className="form-control"
                  value={dishName}
                  onChange={(e) => setDishName(e.target.value)}
                  placeholder="E.g., Spaghetti Carbonara"
                  required
                />
                <small className="form-text text-muted">
                  Only letters and spaces are allowed.
                </small>
              </div>
              <button
                type="submit"
                className="btn btn-primary btn-block"
                disabled={isProcessing}
              >
                {isProcessing ? (
                  <span>
                    <i className="fa-solid fa-spinner fa-spin mr-2"></i>
                    Processing...
                  </span>
                ) : (
                  <span>
                    <i className="fa-solid fa-search mr-2"></i>
                    Decode Ingredients
                  </span>
                )}
              </button>
            </form>
          </div>
        </div>
      </section>

      <section className="image-upload-section mb-5">
        <div className="card">
          <div className="card-body">
            <h2 className="h4 mb-4">Decode Menu Image</h2>
            <div className="custom-file mb-3">
              <input
                type="file"
                className="custom-file-input"
                id="image_file"
                accept="image/*"
                onChange={handleImageUpload}
              />
              <label className="custom-file-label" htmlFor="image_file">
                <i className="fa-solid fa-upload mr-2"></i>
                Choose file...
              </label>
            </div>
            <small className="form-text text-muted mt-2">
              Supported formats: JPG, PNG, GIF
            </small>
          </div>
        </div>
      </section>

      {showTextSelection && detectedText.length > 0 && (
        <section className="detected-text-section mb-5">
          <div className="card">
            <div className="card-header bg-light">
              <h3 className="h5 mb-0">
                Detected Menu Items ({detectedText.length})
              </h3>
            </div>
            <div className="card-body">
              <div className="list-group">
                {detectedText.map((text, index) => (
                  <button
                    key={index}
                    className="list-group-item list-group-item-action"
                    onClick={() => {
                      setDishName(text);
                      setShowTextSelection(false);
                      window.scrollTo({ top: 0, behavior: "smooth" });
                    }}
                  >
                    {text}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>
      )}

      {error && (
        <div className="alert alert-danger" role="alert">
          <i className="fa-solid fa-exclamation-triangle mr-2"></i>
          {error}
        </div>
      )}

      {progressInfo && (
        <div className="progress-container mt-4">
          <div className="progress">
            <div
              className="progress-bar progress-bar-striped progress-bar-animated"
              style={{ width: `${progress}%` }}
            >
              {progress}%
            </div>
          </div>
          <p className="text-center text-muted mt-2">{progressMessage}</p>
        </div>
      )}
    </div>
  );
}
