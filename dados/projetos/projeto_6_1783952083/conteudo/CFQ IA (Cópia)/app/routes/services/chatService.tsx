
"use client";

//Código para colocar as chaves da API do chatGPT.
import { useEffect } from 'react'
import { useState } from 'react';
import Chat from '../layout/chatLayout';
import { useNavigate, useLocation } from "react-router";
import { aviso } from '~/alertas/swal';

export default function ChatService() {

    const [campoDigitado, setCampoDigitado] = useState('');
    const [Mensagem, setMensagem] = useState <any[]>([]);
    const [user, setUser] = useState<any | null>(null);
 
    const navigate = useNavigate();
    const location = useLocation();

    useEffect(() => { //useEffect pra rodar só quando o código for montado.

        const iniciar = async () => {

            aviso('');
            await Validacao();

        };

        iniciar();
    
    }, []);


    const Validacao = async () => {
        console.log("Verificando se usuário está logado...")

    try {
        const validar = await fetch("http://localhost:3700/st", {
            credentials: "include",
            method: "GET",
        }); 

        const validado = await validar.json()
        console.log("O usuário foi validado:", validado)
        console.log("tipo:", typeof validado)

        if(validado){
            setUser(validado);
            return true;

        } else {
            alert ("Ops! Ocorreu um erro na validação do usuário. Tente novamente!")
            navigate("/login")
        };


    } catch (error) {
        alert("Opa, esse usuário não está logado ou não foi encontrado, tente novamente" + error)
        navigate("/login")
        console.log("Erro, verifique o servidor ou a autenticaçõ de usuário")
    }
   } 

   const RespostaDaApi = async (_id: any) => {
         console.log('Verificando servidor do chat')

    try {

        const tscpcndc = await fetch(`http://localhost:3701/gepeto/${_id}`, { //tspcndc = To Sem Criatividade Pra Criar o Nome Dessa Const
          credentials: "include",
          method: "GET", //GET pra ler os dados enviados ao servidor

        });
 
        const Visualizar = await tscpcndc.json(); //Pega a resposta da API em JSON
        console.log("Status:", Visualizar.status, "Tipo:", typeof Visualizar.status); //se o servidor funcionar ele mostra o status
        console.log('Dados renderizando normalmente na tela') //mostra no console a resposta do servidor, CASO funcione.

        if(Visualizar.status === "concluído" && Visualizar.resposta) {
            setMensagem(prev => [...prev, { //prev pega todas as mensagens que já estão na tela e adiciona a resposta do gepeto no final
                autor: "gepeto",
                texto: Visualizar.resposta}]); 
            return;
            
            //se o status for "concluído" o chat atualiza.
        } else {

            setTimeout(() => {
            RespostaDaApi(_id)}, 1000); 
            
        };
    
    } catch (err) {
        alert('Algo deu errado! Erro [DaltonAPI]: ' + err);
        console.error('ERRO na resposta da API')
       setTimeout(() => RespostaDaApi(_id), 3000)//se der erro, ele pega as mensagens da tela também. e retorna um erro.

    }
   }

    const Submit = async (e: React.SubmitEvent) => {
        e.preventDefault();

        console.log('Enviando mensagem...');
        console.log('Mensagem enviada', campoDigitado)

    try {

       const apiMensagem = await fetch ('http://localhost:3701/chat/nova-mensagem', {
        method: "POST", //Campo para enviar a mensagem para a API 
        credentials: "include",
        headers: {
       "Content-Type": "application/json",
      },

      body: JSON.stringify({campoDigitado: campoDigitado})
    });

    const enviado = await apiMensagem.json();
    console.log('Mensagem do usuário:', enviado);

    setMensagem (prev => [...prev, {
        autor: "user",
        texto: campoDigitado
    }]); //adiciona a mensagem ao array 
    setCampoDigitado(''); //limpa o campo após enviar a mensagem

    if(enviado.mensagem && enviado.mensagem._id) {
        RespostaDaApi(enviado.mensagem._id)
    } 

} catch  (err) {
    console.log('Opa! Algo deu errado na conexão', err);
}

}

 const Historico = async () => {
    
    if(!user) {
        console.log('Não há usuário.')
        return;
    } 

    try {
        const historyApi = await fetch("http://localhost:3701/chat/historico", {
        method: 'GET',
        credentials: "include",
        headers: {
            "Content-Type": "application/json",
            
        }

        });

        const historicoObtido = await historyApi.json();
        console.log(historicoObtido)

        const mensagensFormatadas = [...historicoObtido] //dentro de [] pra não mudar o endereço do array original
        .reverse()
        .map((item: any) => ({
            autor: item.role === "user" ? "user" : "gepeto",
            texto: item.content,
        }));

        setMensagem(mensagensFormatadas)


    } catch (err) {
        console.log("Algo deu errado ao obter o histórico")

    } 
    
 }

   const logout = async () => {
    await fetch("http://localhost:3700/logout", {
        method: "POST",
        credentials: "include"
    });

    setUser(null);
    navigate("/");
    
   }


 const voltar = () => {
      const from = location.state?.from; 

        if (from === "portifolio") { 
            navigate ("/portifolio")
        } else if (from === "inicio" && from === "enter" && from !== "portifolio") {
            navigate ("/")
        } else {
            navigate (-1)
        }
   }

   const entre = () => {

    navigate ("/enter")

   }

   const profile = () => {

    navigate ("/perfil")

   }
    return (
        <>
        < Chat
        campoDigitado={campoDigitado}
        setCampoDigitado={setCampoDigitado}
        Mensagem={Mensagem}
        Submit={Submit}
        voltar={voltar} 
        entre={entre}
        user={user}
        setUser={setUser}
        logout={logout}
        profile={profile} />

        </>
    )

}

/* Em geral, esse código é responsável por gerenciar o chat, não só isso como também permitir a entrada do usuário passando as 
informações de uma porta pra outra através da URL e permitindo que ele continue logado. */ 