"use client";

import { motion } from "framer-motion";
import { useNavigate, useLocation } from "react-router";

export default function CadastrarLogin(routes: any) {
  const navigate = useNavigate();
  const location = useLocation();

  const loginPage = () => {
    navigate("/login");
  };

  const SubsPage = () => {
    navigate("/subscribe");
  };

  return (
    <div className="min-h-screen bg-black text-gray-100 font-sans flex items-center justify-center p-6 relative overflow-hidden">
      
      {/* BOTÃO VOLTAR PARA O CHAT */}
      <motion.button
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        onClick={() => navigate("/")}
        className="absolute top-8 left-8 p-3 text-gray-500 hover:text-white hover:bg-gray-900 rounded-full transition-all group flex items-center gap-2"
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 transform group-hover:-translate-x-1 transition-transform">
          <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
        </svg>
        <span className="text-xs font-bold uppercase tracking-widest hidden sm:inline">Voltar</span>
      </motion.button>

      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-blue-600/5 blur-[150px] rounded-full pointer-events-none" />

      <motion.section
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.5 }}
        className="max-w-md w-full z-10 text-center"
      >
        <div className="mb-12">
          <motion.h1
            initial={{ y: -20 }}
            animate={{ y: 0 }}
            className="text-5xl font-black tracking-tighter mb-4"
          >
            Vamos <span className="text-blue-600">iniciar?</span>
          </motion.h1>
          <p className="text-gray-500 font-light">
            Escolha como deseja acessar a plataforma.
          </p>
        </div>

        <div className="space-y-4">
          <motion.button
            whileHover={{ scale: 1.02, backgroundColor: "rgb(103, 181, 255)" }}
            whileTap={{ scale: 0.98 }}
            onClick={() => {
  
              loginPage();
            }}
            className="w-full py-5 bg-blue-600 text-white rounded-2xl font-bold text-lg shadow-[0_0_30px_rgba(37,99,235,0.2)] transition-all flex items-center justify-center gap-3"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-6 h-6">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9" />
            </svg>
            Entrar na conta
          </motion.button>

          <motion.button
            whileHover={{ scale: 1.02, borderColor: "rgba(18,18,18,1)" }}
            whileTap={{ scale: 0.98 }}
            onClick={() => {
              SubsPage();
            }}
            className="w-full py-5 bg-transparent border border-gray-800 text-gray-300 rounded-2xl font-medium text-lg hover:bg-gray-900 transition-all flex items-center justify-center gap-3"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-6 h-6">
              <path strokeLinecap="round" strokeLinejoin="round" d="M18 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0ZM3 19.235v-.11a6.375 6.375 0 0 1 12.75 0v.109A12.318 12.318 0 0 1 9.375 21 12.318 12.318 0 0 1 3 19.235Z" />
            </svg>
            Criar novo perfil
          </motion.button>
        </div>

        <div className="mt-16 flex items-center justify-center gap-4">
          <div className="h-[1px] w-12 bg-gray-800" />
          <span className="text-[10px] text-gray-600 uppercase tracking-widest font-bold">
            Secure Access
          </span>
          <div className="h-[1px] w-12 bg-gray-800" />
        </div>
      </motion.section>
    </div>
  );
}