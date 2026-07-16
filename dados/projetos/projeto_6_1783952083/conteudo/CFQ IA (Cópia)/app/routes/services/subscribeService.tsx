"use client";

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import  Cadastro from '../layout/subscribeForm'

export default function Subscribe() {

  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [nome, setNome] = useState('');

  const navigate = useNavigate();

  const handleSubscribe = async (e: React.SubmitEvent) => {
    e.preventDefault();

    try {
      const apiCadastro = await fetch("http://localhost:3700/subscribe", {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email, senha: senha, nome: nome })
      });

      const data = await apiCadastro.json();

      if (!apiCadastro.ok) {
        console.error("Erro backend:", data);
       
        return;
      } //tratamendo de erro pra caso ocorra algum erro na hora da inscrição.

      console.log("Cadastro enviado com sucesso:", data);

      console.log("Navegado pra login...")

      navigate("/login") //Cadastro foi validado? Vai direto pra login

    } catch (err) {
      console.error("Erro no fetch:", err);
      
    }
  };



  return (

    <>   
    
     <Cadastro
      email={email}
      setEmail={setEmail}
      setSenha={setSenha}
      senha={senha}
      SubmitSubs={handleSubscribe}
      nome={nome}
      setNome={setNome}
      
    />

    </>

    


  );
}
