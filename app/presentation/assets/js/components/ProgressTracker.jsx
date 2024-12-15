import React, { useState, useEffect } from "react";

export default function ProgressTracker({
  channelId,
  fayeEndpoint,
  onComplete,
  onError,
}) {
  const [progress, setProgress] = useState(0);
  const [message, setMessage] = useState("Initializing...");
  const [error, setError] = useState(null);

  useEffect(() => {
    // Load Faye client script dynamically
    const script = document.createElement("script");
    script.src = `${fayeEndpoint}/faye/faye.js`;
    script.async = true;

    script.onload = () => {
      // Initialize Faye client after script loads
      try {
        const fayeClient = new window.Faye.Client(fayeEndpoint, {
          timeout: 120,
          retry: 5,
        });

        // Subscribe to progress channel
        const subscription = fayeClient.subscribe(
          `/progress/${channelId}`,
          (data) => {
            try {
              const parsedData =
                typeof data === "string" ? JSON.parse(data) : data;

              if (parsedData.error) {
                setError(parsedData.error);
                onError && onError(parsedData.error);
                return;
              }

              const percent = parseInt(parsedData.percentage || 0, 10);
              setProgress(percent);
              setMessage(parsedData.message || "Processing...");

              if (percent === 100) {
                setTimeout(() => {
                  onComplete && onComplete();
                }, 1000);
              }
            } catch (err) {
              console.error("Progress data parsing error:", err);
              setError("Failed to process update");
              onError && onError("Failed to process update");
            }
          }
        );

        // Connection status handling
        fayeClient.on("transport:up", () => {
          setMessage("Connected to processing server...");
        });

        fayeClient.on("transport:down", () => {
          setMessage("Reconnecting to server...");
        });

        // Cleanup subscription
        return () => {
          subscription.cancel();
          fayeClient.disconnect();
        };
      } catch (err) {
        console.error("Faye client error:", err);
        setError("Failed to connect to progress tracker");
        onError && onError("Failed to connect to progress tracker");
      }
    };

    script.onerror = () => {
      setError("Failed to load progress tracking system");
      onError && onError("Failed to load progress tracking system");
    };

    document.body.appendChild(script);

    return () => {
      document.body.removeChild(script);
    };
  }, [channelId, fayeEndpoint, onComplete, onError]);

  return (
    <div className="progress-container p-4">
      <div className="text-center mb-4">
        <h4 className="text-muted">{message}</h4>
      </div>

      <div className="progress">
        <div
          className={`progress-bar progress-bar-striped ${
            error ? "bg-danger" : "bg-success"
          } ${!error && progress < 100 ? "progress-bar-animated" : ""}`}
          role="progressbar"
          style={{ width: `${progress}%` }}
          aria-valuenow={progress}
          aria-valuemin="0"
          aria-valuemax="100"
        >
          {progress}%
        </div>
      </div>

      {error && (
        <div className="alert alert-danger mt-4">
          <p className="mb-1">
            <strong>Error:</strong> {error}
          </p>
          <button
            onClick={() => window.location.reload()}
            className="btn btn-sm btn-outline-danger"
          >
            Retry
          </button>
        </div>
      )}
    </div>
  );
}
