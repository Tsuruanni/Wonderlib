import { ImageResponse } from "next/og";

export const alt = "Owlio — The fun way to read in English";

export const size = {
  width: 1200,
  height: 630,
};

export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background: "#58CC02",
          fontFamily: "sans-serif",
        }}
      >
        {/* Owl eyes */}
        <div style={{ display: "flex", gap: "8px", marginBottom: "16px" }}>
          <div
            style={{
              width: "64px",
              height: "64px",
              borderRadius: "50%",
              background: "white",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <div
              style={{
                width: "32px",
                height: "32px",
                borderRadius: "50%",
                background: "#4B4B4B",
              }}
            />
          </div>
          <div
            style={{
              width: "64px",
              height: "64px",
              borderRadius: "50%",
              background: "white",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <div
              style={{
                width: "32px",
                height: "32px",
                borderRadius: "50%",
                background: "#4B4B4B",
              }}
            />
          </div>
        </div>
        <div
          style={{
            fontSize: "72px",
            fontWeight: "900",
            color: "white",
            letterSpacing: "-0.02em",
            marginBottom: "8px",
          }}
        >
          owlio
        </div>
        <div
          style={{
            fontSize: "28px",
            fontWeight: "700",
            color: "rgba(255,255,255,0.85)",
          }}
        >
          The fun way to read in English
        </div>
      </div>
    ),
    { ...size }
  );
}
