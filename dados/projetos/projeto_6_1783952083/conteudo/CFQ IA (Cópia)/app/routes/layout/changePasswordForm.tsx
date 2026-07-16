
import { motion } from "framer-motion";

export default function ChangePassword(config: any) {
  const {
    senhaAtual,
    novaSenha,
    confirmarSenha,
    setSenhaAtual,
    setNovaSenha,
    setConfirmarSenha,
    trocarsenha,
    carregando,
  } = config;

  return (

    
    <div className="min-h-screen bg-black text-gray-100 font-sans flex flex-col items-center justify-center p-6 relative overflow-hidden">
        
      {/* Glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[500px] h-[300px] bg-blue-600/10 blur-[120px] rounded-full pointer-events-none" />

      <motion.section
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.5 }}
        className="max-w-md w-full z-10 p-8 rounded-2xl bg-blue-600/5 border border-blue-600/20 backdrop-blur-sm"
      >
        <h1 className="text-3xl font-extrabold mb-8 tracking-tighter text-center">
          Alterar <span className="text-blue-600">Senha</span>
        </h1>

        <form onSubmit={trocarsenha} className="space-y-6">

          {/* Senha atual */}
          <div>
            <label className="block text-sm font-medium mb-2 text-blue-500/80 uppercase tracking-widest">
              Senha atual
            </label>
            <input
              type="password"
              value={senhaAtual}
              onChange={(e) => setSenhaAtual(e.target.value)}
              className="w-full px-4 py-3 bg-white/5 border border-blue-600/20 rounded-xl focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-all text-gray-200"
              required
            />
          </div>

          {/* Nova senha */}
          <div>
            <label className="block text-sm font-medium mb-2 text-blue-500/80 uppercase tracking-widest">
              Nova senha
            </label>
            <input
              type="password"
              value={novaSenha}
              onChange={(e) => setNovaSenha(e.target.value)}
              className="w-full px-4 py-3 bg-white/5 border border-blue-600/20 rounded-xl focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-all text-gray-200"
              required
            />
          </div>

          {/* Confirmar senha */}
          <div>
            <label className="block text-sm font-medium mb-2 text-blue-500/80 uppercase tracking-widest">
              Confirmar nova senha
            </label>
            <input
              type="password"
              value={confirmarSenha}
              onChange={(e) => setConfirmarSenha(e.target.value)}
              className="w-full px-4 py-3 bg-white/5 border border-blue-600/20 rounded-xl focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-all text-gray-200"
              required
            />
          </div>

          <button
            type="submit"
            disabled={carregando}
            className="w-full py-4 bg-blue-600 text-white rounded-xl font-bold uppercase tracking-widest hover:bg-blue-500 active:scale-95 transition-all disabled:opacity-50"
          >
            {carregando ? "Alterando..." : "Alterar senha"}
          </button>
        </form>
      </motion.section>

      <footer className="mt-12 text-[10px] text-gray-700 uppercase tracking-[0.2em] font-medium z-10">
        POWERED by Adria Cortez
      </footer>
    </div>
  );
}
