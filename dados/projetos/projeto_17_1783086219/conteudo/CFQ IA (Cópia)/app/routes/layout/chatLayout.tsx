"use client";

import { motion, AnimatePresence } from 'framer-motion';
import { useState } from 'react';

export default function Chat(Message: any) {
    const {
        campoDigitado,
        setCampoDigitado,
        Submit,
        Mensagem,
        voltar, 
        entre, 
        user,
        logout,
        profile
    } = Message;

    const [showLogout, setShowLogout] = useState(false);
    const [isSidebarOpen, setIsSidebarOpen] = useState(false);

    return (
        <div className="flex h-screen bg-black text-gray-100 font-sans overflow-hidden">
            
            <AnimatePresence>
                {isSidebarOpen && (
                    <>
                        <motion.div 
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 0.8 }}
                            exit={{ opacity: 0 }}
                            onClick={() => setIsSidebarOpen(false)}
                            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-40"
                        />
                        
                        <motion.aside
                            initial={{ x: -300 }}
                            animate={{ x: 0 }}
                            exit={{ x: -300 }}
                            transition={{ type: "spring", damping: 20, stiffness: 100 }}
                            className="fixed left-0 top-0 h-full w-72 bg-gray-950 border-r border-gray-800 z-50 p-6 flex flex-col"
                        >
                            <div className="flex items-center justify-between mb-8">
                                <h2 className="text-blue-500 font-bold text-lg uppercase tracking-wider">Histórico</h2>
                                <button onClick={() => setIsSidebarOpen(false)} className="text-gray-500 hover:text-white">
                                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-6 h-6">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18 18 6M6 6l12 12" />
                                    </svg>
                                </button>
                            </div>

                            <div className="flex-1 overflow-y-auto space-y-3 pr-2 custom-scrollbar">
                                {Mensagem.length > 0 ? (
                                    Mensagem.filter((m: any) => m.autor === "user").map((msg: any, i: number) => (
                                        <div key={i} className="p-3 bg-gray-900/50 border border-gray-800 rounded-xl hover:border-blue-500/50 transition-colors cursor-pointer group">
                                            <p className="text-xs text-gray-500 mb-1">Chat #{i + 1}</p>
                                            <p className="text-sm text-gray-300 truncate group-hover:text-blue-400">
                                                {msg.texto}
                                            </p>
                                        </div>
                                    ))
                                ) : (
                                    <p className="text-gray-600 text-sm text-center mt-10">Nenhuma conversa recente.</p>
                                )}
                            </div>

                            <div className="mt-auto pt-6 border-t border-gray-800">
                                <button className="w-full py-3 bg-gray-900 hover:bg-gray-800 text-gray-300 rounded-xl text-sm transition-all border border-gray-800">
                                    + Nova Conversa
                                </button>
                            </div>
                        </motion.aside>
                    </>
                )}
            </AnimatePresence>

            <div className="flex-1 flex flex-col h-full relative">
                
                <motion.header 
                    initial={{ opacity: 0, y: -20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.8 }}
                    className="py-4 border-b border-gray-800 bg-black/50 backdrop-blur-md sticky top-0 z-10 flex items-center justify-center px-4"
                >
                    <button 
                        onClick={() => setIsSidebarOpen(true)}
                        className="absolute left-16 p-2 text-gray-400 hover:text-blue-500 hover:bg-gray-900 rounded-lg transition-all"
                        title="Histórico"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-6 h-6">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
                        </svg>
                    </button>
                
                    <button 
                        onClick={voltar}
                        className="absolute left-4 p-2 text-gray-400 hover:text-blue-500 hover:bg-gray-900 rounded-full transition-all group"
                        title="Voltar"
                    >
                        <svg 
                            xmlns="http://www.w3.org/2000/svg" 
                            fill="none" 
                            viewBox="0 0 24 24" 
                            strokeWidth={2} 
                            stroke="currentColor" 
                            className="w-6 h-6 transform group-hover:-translate-x-1 transition-transform"
                        >
                            <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
                        </svg>
                    </button>

                    <h1 className="text-xl font-bold tracking-tight text-blue-600">
                         Dalton <span className="text-gray-400 font-light">AI (beta 1.1)</span>
                    </h1>

                    <div 
                        className="absolute right-4 flex items-center"
                        onMouseEnter={() => setShowLogout(true)}
                        onMouseLeave={() => setShowLogout(false)}
                    >
                        { user ? ( 
                            <div className="relative">
                                <span className='p-2 text-gray-400 cursor-default border border-transparent hover:border-gray-800 rounded-full transition-all'>
                                    Olá, <span className="text-blue-500 font-semibold">{user.nome}</span>
                                </span>

                                <AnimatePresence>
                                    {showLogout && (
                                        <motion.div 
                                            initial={{ opacity: 0, scale: 0.95, y: -10 }}
                                            animate={{ opacity: 1, scale: 1, y: 0 }}
                                            exit={{ opacity: 0, scale: 0.95, y: -10 }}
                                            className="absolute right-0 mt-2 w-48 bg-gray-900 border border-gray-800 rounded-2xl shadow-2xl overflow-hidden z-50 p-1"
                                        >
                                            <button 
                                                onClick={() => profile && profile()}
                                                className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-400 hover:bg-blue-500/10 rounded-xl transition-colors group">
                                                <span className="font-bold uppercase tracking-tighter">Meu perfil</span>
                                            </button>
                                            <button 
                                                onClick={() => logout && logout()}
                                                className="w-full flex items-center gap-3 px-4 py-3 text-sm text-red-400 hover:bg-red-500/10 rounded-xl transition-colors group"
                                            >
                                                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 group-hover:scale-110 transition-transform">
                                                    <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9" />
                                                </svg>
                                                <span className="font-bold uppercase tracking-tighter">Sair da conta</span>
                                            </button>
                                        </motion.div>
                                    )}
                                </AnimatePresence>
                            </div>
                        ) : null }
                    </div>
                </motion.header>

                {/* --- CONTAINER DE MENSAGENS COM AUTO-SCROLL (CSS ONLY) --- */}
                <main className="flex-1 overflow-y-auto p-4 scrollbar-hide flex flex-col-reverse">
                    <section className="max-w-3xl mx-auto w-full flex flex-col space-y-4">
                        {Mensagem.length === 0 && (
                            <motion.div 
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 1 }}
                                className="text-center py-20 text-gray-600"
                            >
                                <p className="text-lg">Como posso te ajudar hoje?</p>
                            </motion.div>
                        )}

                        {Mensagem.map((msg: any, index: number) => (
                            <motion.div
                                key={index}
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                className={`flex ${msg.autor === "user" ? "justify-end" : "justify-start"}`}
                            >
                                <div
                                    className={`max-w-[85%] sm:max-w-[70%] px-5 py-3 rounded-2xl shadow-lg leading-relaxed ${
                                        msg.autor === "user"
                                            ? "bg-gray-800 text-gray-100 rounded-tr-none border border-gray-700"
                                            : "bg-blue-700 text-white rounded-tl-none border border-blue-800"
                                    }`}
                                >
                                    <p className="text-sm font-semibold mb-1 opacity-70">
                                        {msg.autor === "user" ? "Você" : "Dalton"}
                                    </p>
                                    <span className="text-[15px] whitespace-pre-wrap">{msg.texto}</span>
                                </div>
                            </motion.div>
                        ))}
                    </section>
                </main>

                {/* --- FOOTER COM TEXTAREA EXPANSÍVEL (CSS ONLY) --- */}
                <motion.footer 
                    initial={{ opacity: 0, y: 50 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="p-4 bg-gradient-to-t from-black via-black to-transparent"
                >
                    <form 
                        onSubmit={Submit} 
                        className="max-w-3xl mx-auto relative flex items-end gap-2 bg-gray-900 border border-gray-800 rounded-[26px] p-2 focus-within:ring-2 focus-within:ring-blue-600 transition-all shadow-2xl"
                    >
                        <textarea 
                            value={campoDigitado} 
                            onChange={(e) => setCampoDigitado(e.target.value)} 
                            placeholder="Mande uma mensagem para Dalton..." 
                            rows={1}
                            style={{ fieldSizing: 'content' } as any}
                            className="w-full bg-transparent text-white px-4 py-3 min-h-[44px] max-h-[200px] resize-none focus:outline-none placeholder:text-gray-600 text-base custom-scrollbar"
                            required
                            onKeyDown={(e) => {
                                if (e.key === 'Enter' && !e.shiftKey) {
                                    e.preventDefault();
                                    e.currentTarget.form?.requestSubmit();
                                }
                            }}
                        />
                        <button 
                            type="submit" 
                            className="mb-1 mr-1 p-3 bg-blue-600 text-white rounded-full hover:bg-blue-700 hover:scale-105 active:scale-95 transition-all shadow-lg flex-shrink-0"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-5 h-5">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M6 12 3.269 3.125A59.769 59.769 0 0 1 21.485 12 59.768 59.768 0 0 1 3.27 20.875L5.999 12Zm0 0h7.5" />
                            </svg>
                        </button>
                    </form>
                    <p className="text-[10px] text-center text-gray-700 mt-2 uppercase tracking-widest font-medium">
                        Powered by Adria Cortez & Lucas Salles
                    </p>
                </motion.footer>
            </div>
        </div>
    );
}