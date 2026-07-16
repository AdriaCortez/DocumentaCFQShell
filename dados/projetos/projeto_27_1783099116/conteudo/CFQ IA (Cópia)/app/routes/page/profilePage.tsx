"use client";

import { motion, AnimatePresence } from 'framer-motion';
import { useLocation } from "react-router";
import { useNavigate } from "react-router";
import { useEffect, useState } from "react";

export default function Profile (config: any) {

  const { deletarconta, user, setUser} = config;
  const [modalaberto, setModalAberto] = useState(false);
  const [modalDeletarAberto, setModalDeletarAberto] = useState(false);
  const [senhaConfirmacao, setSenhaConfirmacao] = useState("");

  const location = useLocation();
  const navigate = useNavigate();

  console.log("Usuario no perfil", user)

  return (
    <div className="flex flex-col h-screen bg-black text-gray-100 font-sans overflow-hidden">
      
      {/* Header */}
      <motion.header 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="py-4 border-b border-gray-800 bg-black/50 backdrop-blur-md sticky top-0 z-10 flex items-center justify-center px-4"
      >
        <button 
          onClick={() => navigate(`/chat?user=${user?._id}`)}
          className="absolute left-4 p-2 text-gray-400 hover:text-blue-500 hover:bg-gray-900 rounded-full transition-all group"
        >
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-6 h-6 transform group-hover:-translate-x-1 transition-transform">
            <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
          </svg>
        </button>

        <h1 className="text-xl font-bold tracking-tight text-blue-600">
          Meu <span className="text-gray-400 font-light">Perfil</span>
        </h1>
      </motion.header>

      <main className="flex-1 flex flex-col items-center justify-center p-4">
        <motion.div 
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="w-full max-w-md bg-gray-900/50 border border-gray-800 p-8 rounded-3xl shadow-2xl text-center"
        >
          <div className="w-24 h-24 bg-blue-600 rounded-full mx-auto mb-6 flex items-center justify-center text-3xl font-bold shadow-[0_0_20px_rgba(37,99,235,0.4)]">
            {user?.nome?.charAt(0).toUpperCase() || "U"}
          </div>

          <h2 className="text-2xl font-bold text-white mb-2">{user?.nome || "Usuário"}</h2>
          <p className="text-gray-500 mb-8">{user?.email || "email@exemplo.com"}</p>

          <div className="space-y-3">
            <button 
              onClick={() => setModalAberto(true)}
              className="w-full py-3 px-6 bg-gray-800 hover:bg-gray-700 text-white rounded-xl font-semibold transition-all border border-gray-700 flex items-center justify-center gap-2"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12a7.5 7.5 0 1 1 15 0 7.5 7.5 0 0 1-15 0Z" />
                <path strokeLinecap="round" strokeLinejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7Z" />
              </svg>
              Configurações
            </button>
          </div>
        </motion.div>
      </main>

      {/* Modal de Configurações */}
      <AnimatePresence>
        {modalaberto && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div 
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setModalAberto(false)}
              className="absolute inset-0 bg-black/80 backdrop-blur-sm"
            />
            <motion.div 
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="relative w-full max-w-sm bg-gray-900 border border-gray-800 rounded-3xl p-6 shadow-2xl"
            >
              <h3 className="text-xl font-bold text-blue-500 mb-4">Configurações</h3>
              
              <div className="space-y-2">
                <button 
                  onClick={() => navigate("/trocar-senha")}
                  className="w-full flex items-center gap-3 px-4 py-4 text-gray-300 hover:bg-blue-600/10 hover:text-blue-400 rounded-2xl transition-all border border-transparent hover:border-blue-900/50"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 5.25a3 3 0 0 1 3 3m3 0a6 6 0 0 1-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1 1 21.75 8.25Z" />
                  </svg>
                  <span className="font-bold uppercase tracking-tighter text-sm">Alterar Senha</span>
                </button>

                {/* BOTÃO QUE ABRE O SEGUNDO MODAL */}
                <button 
                  onClick={() => setModalDeletarAberto(true)}
                  className="w-full flex items-center gap-3 px-4 py-4 text-red-500/70 hover:bg-red-600/10 hover:text-red-500 rounded-2xl transition-all border border-transparent hover:border-red-900/50"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
                    <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                  </svg>
                  <span className="font-bold uppercase tracking-tighter text-sm">Deletar Conta</span>
                </button>

                <button 
                  onClick={() => setModalAberto(false)}
                  className="w-full mt-4 py-3 text-gray-500 hover:text-white transition-colors text-sm font-medium"
                >
                  Fechar
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
      
      <AnimatePresence>
        {modalDeletarAberto && (
          <div className="fixed inset-0 z-[60] flex items-center justify-center p-4">
            <motion.div 
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => {
                setModalDeletarAberto(false);
                setSenhaConfirmacao("");
              }}
              className="absolute inset-0 bg-black/90 backdrop-blur-md"
            />
            <motion.div 
              initial={{ opacity: 0, scale: 0.9, y: 10 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.9, y: 10 }}
              className="relative w-full max-w-sm bg-gray-900 border border-red-900/30 rounded-3xl p-8 shadow-[0_0_50px_rgba(220,38,38,0.15)]"
            >
              <h3 className="text-xl font-bold text-red-500 mb-2">Confirmar Exclusão</h3>
              <p className="text-gray-400 text-sm mb-6">Esta ação apagará permanentemente sua conta e não pode ser desfeita.</p>
              
              <div className="space-y-4">
                <input 
                  type="password"
                  placeholder="Senha de confirmação"
                  value={senhaConfirmacao}
                  onChange={(e) => setSenhaConfirmacao(e.target.value)}
                  className="w-full bg-black border border-gray-800 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-red-600 transition-colors"
                />

                <button 
                  onClick={() => deletarconta(senhaConfirmacao)}
                  disabled={!senhaConfirmacao}
                  className="w-full py-4 bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-xl font-bold uppercase tracking-widest text-xs transition-all shadow-lg shadow-red-900/20"
                >
                  Deletar Permanentemente
                </button>

                <button 
                  onClick={() => {
                    setModalDeletarAberto(false);
                    setSenhaConfirmacao("");
                  }}
                  className="w-full text-gray-500 hover:text-gray-300 text-sm transition-colors"
                >
                  Voltar
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      <footer className="p-4 text-center">
        <p className="text-[10px] text-gray-700 uppercase tracking-widest font-medium">
          ACESSO SEGURO E PROTEGIDO PELAS POLÍTICAS DE PRIVACIDADE DE DALTON AI E DO CONSELHO FEDERAL DE QUÍMICA.
        </p>
      </footer>
    </div>
  );
}