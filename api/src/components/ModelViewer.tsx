"use client";

import { useEffect, useRef } from "react";

interface Props {
  glbUrl: string;
  usdzUrl?: string;
  alt?: string;
}

export function ModelViewer({ glbUrl, usdzUrl, alt = "3D Room Model" }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Dynamically import model-viewer to avoid SSR issues
    import("@google/model-viewer");
  }, []);

  return (
    <div ref={containerRef} className="w-full h-[400px] bg-gray-100 rounded-lg overflow-hidden relative">
      <model-viewer
        src={glbUrl}
        ios-src={usdzUrl}
        alt={alt}
        ar
        ar-modes="webxr scene-viewer quick-look"
        camera-controls
        touch-action="pan-y"
        auto-rotate
        shadow-intensity="1"
        environment-image="neutral"
        style={{ width: "100%", height: "100%" }}
      >
        <div className="absolute bottom-4 left-4 right-4 flex justify-center">
          <button
            slot="ar-button"
            className="bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 px-4 rounded-lg shadow-md transition-colors"
          >
            View in AR
          </button>
        </div>
      </model-viewer>
    </div>
  );
}
