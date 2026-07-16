import { Link } from "react-router";
import { motion } from "framer-motion";

export default function HomePage() {
  return (
    <div className="min-h-screen bg-black text-gray-100 font-sans selection:bg-blue-500/30">
      
      <section className="h-screen flex flex-col items-center justify-center p-6 relative overflow-hidden">
    
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[400px] bg-blue-600/10 blur-[120px] rounded-full pointer-events-none" />

        <main className="max-w-4xl w-full text-center z-10 flex flex-col items-center">
          <motion.h1 
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
            className="text-4xl md:text-6xl font-extrabold mb-4 tracking-tighter"
          >
            Bem-vindo à <span className="text-blue-600">IA do CFQ</span>
          </motion.h1>
          
          <motion.p 
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.3, duration: 0.8 }}
            className="text-gray-400 text-lg md:text-xl mb-12 font-light max-w-2xl"
          >
            Respostas precisas para os membros do conselho federal de química
          </motion.p>

          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.5, duration: 0.5 }}
            className="w-full max-w-sm"
          >
            <Link to="/enter" className="group">
              <div className="p-10 rounded-3xl bg-blue-600/5 border border-blue-600/20 hover:border-blue-500 hover:bg-blue-600/10 transition-all duration-500 backdrop-blur-md relative overflow-hidden">
                <div className="absolute top-4 right-4 flex items-center gap-2">
                  <span className="text-[10px] text-blue-400 font-bold uppercase tracking-widest">Beta 1.1</span>
                  <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-blue-500"></span>
                  </span>
                </div>
                
                <h3 className="text-2xl font-bold mb-2 text-white group-hover:text-blue-400 transition-colors">Dalton AI</h3>
                <p className="text-sm text-gray-500 mb-8">Cadastre-se e inicie sua conversa agora</p>
                
                <div className="inline-block px-7 py-3 bg-blue-600 text-white rounded-full text-sm font-bold uppercase tracking-widest shadow-[0_0_20px_rgba(37,99,235,0.3)] group-hover:shadow-[0_0_30px_rgba(37,99,235,0.5)] group-hover:scale-105 transition-all active:scale-95">
                  Iniciar
                </div>
              </div>
            </Link>
          </motion.div>
        </main>

        <motion.div 
          animate={{ y: [0, 10, 0] }}
          transition={{ repeat: Infinity, duration: 2 }}
          className="absolute bottom-10 flex flex-col items-center gap-2 text-gray-600"
        >
          <span className="text-[10px] uppercase tracking-widest">Arraste pra baixo e conheça a inspiração da nossa IA</span>
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
            <path strokeLinecap="round" strokeLinejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
          </svg>
        </motion.div>
      </section>

      <section className="min-h-screen flex items-center justify-center p-6 relative">
        <motion.div 
          initial={{ opacity: 0, y: 50 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 1, ease: "easeOut" }}
          className="max-w-5xl w-full grid md:grid-cols-2 gap-12 items-center"
        >
          <div className="relative group flex justify-center">
            <div className="absolute inset-0 bg-blue-600/20 blur-[80px] rounded-full group-hover:bg-blue-600/30 transition-colors" />
            <img 
              src="https://upload.wikimedia.org/wikipedia/commons/d/d4/John_Dalton_by_Charles_Turner.jpg" 
              alt="John Dalton" 
              className="relative w-72 md:w-full max-w-sm rounded-3xl grayscale opacity-40 hover:grayscale-0 hover:opacity-80 transition-all duration-700 shadow-2xl"
              style={{ maskImage: 'linear-gradient(to bottom, black 80%, transparent 100%)', WebkitMaskImage: 'linear-gradient(to bottom, black 80%, transparent 100%)' }}
            />
          </div>

          <div className="flex flex-col gap-6">
            <div className="h-1 w-20 bg-blue-600 rounded-full" />
            <h2 className="text-3xl md:text-4xl font-bold tracking-tight">Ao Legado de <span className="text-blue-500">John Dalton</span></h2>
            <p className="text-gray-400 text-lg leading-relaxed font-light">
            A Inteligência artificial do CFQ foi baseada no químico, físico e meteorologista, nascido em 1766 na inglaterra e fundador da primeira teoria atômica moderna.
            </p>
            <div className="bg-white/[0.03] border border-white/10 p-6 rounded-2xl backdrop-blur-md">
              <p className="text-gray-300 italic text-sm md:text-base leading-relaxed">
                "Na natureza nada se cria, nada se perde, tudo se transforma."
              </p>
            </div>
            <p className="text-gray-500 text-xs uppercase tracking-[0.2em]">1766 — 1844</p>
          </div>
        </motion.div>
      </section>

      <footer className="py-12 flex flex-col items-center gap-4 border-t border-white/5">
        <p className="text-[10px] text-gray-700 uppercase tracking-[0.3em] font-medium">
          POWERED BY ADRIA CORTEZ
        </p>
      </footer>
    </div>
  );
}