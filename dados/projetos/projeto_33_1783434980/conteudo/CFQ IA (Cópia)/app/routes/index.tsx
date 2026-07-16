import type { Route } from "./+types/index";
import HomePage from "./page/homePage";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "CFQ IA" },
    { name: "description", content: "Bem-vindo à IA do CFQ" },
  ];
}

export default function Home() {
  return <HomePage />;
}
