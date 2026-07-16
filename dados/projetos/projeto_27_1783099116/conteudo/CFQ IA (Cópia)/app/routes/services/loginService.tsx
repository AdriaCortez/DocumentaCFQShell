"use client";

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import Login from '../layout/loginForm';

export default function Enter() {

  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');

  const navigate = useNavigate();
  
  const SubmitedToken = async () => { 

    const res = await fetch("http://localhost:3700/st", {
     method: "GET",
     credentials: "include"

  });

  if(!res.ok) {
    
    throw new Error ("Token inválido");
  }

  const user = await res.json();

  console.log("Usuário autenticado", user);

  navigate("/chat", { state: { user } });
}

   const HandleAuth = async (e: React.SubmitEvent) => {
    e.preventDefault()

    try { console.log('Verificando credenciais...')

    const apiLogin = await fetch("http://localhost:3700/auth-login", {
        method: 'POST', 
        headers: {
            "Content-type": "application/json", }, 

          credentials: "include",
          body: JSON.stringify({ email: email, senha: senha})
        } //fecha as especificações de fetch

    ); //fecha API LOGIN

     if(!apiLogin.ok) {

      alert("Credenciais inválidas. Crie uma conta ou tente novamente")
      return;
     }

     await SubmitedToken();

    } catch {
        alert('Algo deu errado!')
    }
  } 

  return (
    <>

    <Login

    email={email}
    setEmail={setEmail}
    senha={senha}
    setSenha={setSenha}
    HandleAuth={HandleAuth}
    
    />
    

    </>
  )

}