import Link from "next/link";

type ButtonVariant = "green" | "blue" | "neutral";
type ButtonSize = "md" | "lg";

interface ButtonProps {
  children: React.ReactNode;
  href?: string;
  variant?: ButtonVariant;
  size?: ButtonSize;
  onClick?: () => void;
  type?: "button" | "submit";
  className?: string;
}

const variantStyles: Record<ButtonVariant, string> = {
  green:
    "bg-feather text-snow shadow-[0_4px_0_#46A302] hover:brightness-110 active:shadow-none active:translate-y-[4px]",
  blue:
    "bg-snow text-sky shadow-[0_4px_0_#BBE7FC] hover:brightness-95 active:shadow-none active:translate-y-[4px]",
  neutral:
    "bg-snow text-sky border-2 border-swan shadow-[0_2px_0_#E5E5E5] hover:bg-polar hover:border-[#CECECE] hover:shadow-[0_2px_0_#CECECE] active:shadow-none active:translate-y-[2px]",
};

const sizeStyles: Record<ButtonSize, string> = {
  md: "px-6 py-2.5 text-sm",
  lg: "px-8 py-3 text-base min-h-[44px]",
};

export function Button({
  children,
  href,
  variant = "green",
  size = "lg",
  onClick,
  type = "button",
  className = "",
}: ButtonProps) {
  const baseStyles =
    "inline-flex items-center justify-center rounded-duo font-extrabold uppercase tracking-wider transition-all duration-100 text-center cursor-pointer select-none";
  const styles = `${baseStyles} ${variantStyles[variant]} ${sizeStyles[size]} ${className}`;

  if (href) {
    return (
      <Link href={href} className={styles}>
        {children}
      </Link>
    );
  }

  return (
    <button type={type} onClick={onClick} className={styles}>
      {children}
    </button>
  );
}
