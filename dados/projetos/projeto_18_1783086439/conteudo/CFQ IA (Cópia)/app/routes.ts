import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [index("routes/index.tsx"),

    route("/enter", "routes/page/startPage.tsx"),
    route("/login", "routes/services/loginService.tsx"),
    route("/subscribe", "routes/services/subscribeService.tsx"),
    route("/chat", "routes/services/chatService.tsx"),
    route("/perfil", "routes/services/profileService.tsx"),
    route("/trocar-senha", "routes/services/changePasswordService.tsx")

] satisfies RouteConfig;


