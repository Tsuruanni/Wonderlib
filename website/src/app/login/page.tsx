import { redirect } from "next/navigation";
import { APP_LOGIN_URL } from "@/lib/constants";

export default function LoginPage() {
  redirect(APP_LOGIN_URL);
}
