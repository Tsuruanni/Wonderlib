interface OwlLogoProps {
  size?: number;
  className?: string;
}

export function OwlLogo({ size = 32, className = "" }: OwlLogoProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      {/* Body */}
      <ellipse cx="32" cy="38" rx="22" ry="20" fill="#58CC02" />
      {/* Belly */}
      <ellipse cx="32" cy="42" rx="14" ry="13" fill="#89E219" />
      {/* Left eye white */}
      <circle cx="23" cy="28" r="10" fill="white" />
      {/* Right eye white */}
      <circle cx="41" cy="28" r="10" fill="white" />
      {/* Left pupil */}
      <circle cx="25" cy="28" r="5" fill="#4B4B4B" />
      {/* Right pupil */}
      <circle cx="43" cy="28" r="5" fill="#4B4B4B" />
      {/* Left eye shine */}
      <circle cx="27" cy="26" r="2" fill="white" />
      {/* Right eye shine */}
      <circle cx="45" cy="26" r="2" fill="white" />
      {/* Beak */}
      <path d="M28 34 L32 39 L36 34Z" fill="#FFC800" />
      {/* Left ear tuft */}
      <path
        d="M14 20 Q16 10 22 16"
        stroke="#46A302"
        strokeWidth="3"
        strokeLinecap="round"
        fill="none"
      />
      {/* Right ear tuft */}
      <path
        d="M50 20 Q48 10 42 16"
        stroke="#46A302"
        strokeWidth="3"
        strokeLinecap="round"
        fill="none"
      />
      {/* Left foot */}
      <ellipse cx="24" cy="57" rx="5" ry="3" fill="#FFC800" />
      {/* Right foot */}
      <ellipse cx="40" cy="57" rx="5" ry="3" fill="#FFC800" />
    </svg>
  );
}
