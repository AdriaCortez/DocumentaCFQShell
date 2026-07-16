"use client";

import { useState } from "react";
import { useNavigate } from "react-router";
import ChangePassword from "../layout/changePasswordForm";

export default function AlterarSenha() {

  const [senhaatual, setSenhaAtual] = useState('');
  const [novasenha, setNovaSenha] = useState('');
  const [confirmarsenha, setConfirmarSenha] = useState('');
  const [carregando, setCarregando] = useState(false);
  
  const navigate = useNavigate();

  const trocarsenha = async (e: React.SubmitEvent) => {
    e.preventDefault();

    if (novasenha !== confirmarsenha) {
      alert("As senhas não coincidem.");
      return;

    }

    if (!senhaatual) {
      alert("Senha atual incorreta.");
      return;

    }

    setCarregando(true);

    try {
      const apiTrocarSenha = await fetch("http://localhost:3700/trocarsenha", {
        method: "PUT",
        credentials: "include",
        headers: { 
          "Content-Type": "application/json",
        },

        body: JSON.stringify({ senhaatual: senhaatual, confirmarsenha: confirmarsenha, novasenha: novasenha })
      });

      const data = await apiTrocarSenha.json();

      if (!apiTrocarSenha.ok) {
        console.log(data.message || "Erro na hora de trocar senha.")
      }

      setSenhaAtual('');
      setNovaSenha('');
      setConfirmarSenha('');
      setCarregando(false);

      navigate("/perfil") //Redireciona para o perfil após a senha ser alterada

      return; 

    } catch (err) {
      console.log("Erro ao trocar a senha:", err);
      alert("Erro no servidor");
  } } 
  
    return (
        <>
          <ChangePassword
            senhaatual={senhaatual}
            setSenhaAtual={setSenhaAtual}
            novasenha={novasenha}
            setNovaSenha={setNovaSenha}
            confirmarsenha={confirmarsenha}
            setConfirmarSenha={setConfirmarSenha}
            trocarsenha={trocarsenha}
            carregando={carregando}
          />
        </>
        
    ) }