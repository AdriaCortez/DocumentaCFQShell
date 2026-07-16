"use client";

import { motion } from "framer-motion";

export default function Login(config: any) {
  const { 
    email, 
    senha, 
    setEmail, 
    setSenha, 
    HandleAuth 
  } = config;

  return (
    <div className="min-h-screen bg-black text-gray-100 font-sans flex flex-col items-center justify-center p-6 relative overflow-hidden">
      
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[500px] h-[300px] bg-blue-600/10 blur-[120px] rounded-full pointer-events-none" />

      <motion.section 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.5 }}
        className="max-w-md w-full z-10 p-8 rounded-2xl bg-blue-600/5 border border-blue-600/20 backdrop-blur-sm"
      >
        <h1 className="text-4xl font-extrabold mb-8 tracking-tighter text-center">
          Faça seu <span className="text-blue-600">LOGIN</span>
        </h1>

        <form onSubmit={HandleAuth} className="space-y-6">
          
          <div>
            <label className="block text-sm font-medium mb-2 text-blue-500/80 uppercase tracking-widest">
              E-mail:
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="nome.exemplo@mail.com"
              className="w-full px-4 py-3 bg-white/5 border border-blue-600/20 rounded-xl focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-all text-gray-200 placeholder:text-gray-600"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-blue-500/80 uppercase tracking-widest">
              Senha:
            </label>
            <input
              type="password"
              value={senha}
              onChange={(e) => setSenha(e.target.value)}
              placeholder="insira sua senha"
              className="w-full px-4 py-3 bg-white/5 border border-blue-600/20 rounded-xl focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-all text-gray-200 placeholder:text-gray-600"
              required
            />
          </div>

          <button
            type="submit"
            className="w-full py-4 bg-blue-600 text-white rounded-xl font-bold uppercase tracking-widest shadow-[0_0_20px_rgba(219,39,119,0.3)] hover:bg-blue-500 hover:scale-[1.02] active:scale-95 transition-all duration-300 cursor-pointer"
          >
            Entrar
          </button>
        </form>
      </motion.section>

      <footer className="mt-12 text-[10px] text-gray-700 uppercase tracking-[0.2em] font-medium z-10">
        POWERED by Adria Cortez
      </footer>
    </div>
  );
}