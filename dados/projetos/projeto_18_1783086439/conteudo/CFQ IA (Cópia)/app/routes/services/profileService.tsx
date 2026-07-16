"use client";

import Profile from "../page/profilePage";
import { useNavigate } from "react-router";
import { useEffect, useState } from "react";

export default function Perfil() {

    const [user, setUser] = useState<any>(null);
    
    const navigate = useNavigate();

    useEffect(() => {
        async function validarUser() {
            try {
                const validation = await fetch("http://localhost:3700/st", {
                    credentials: "include",
                });

                const data = await validation.json();

                console.log("Usuario no perfil:", data)
                setUser(data);

                 if(!data || !data._id) {
                    navigate("/enter")
                }


            } catch (err) {
                alert("Opa! Algo na validação deu errado")
                console.log(err);
            }
        }

        validarUser()
    }, [])

    const deletarconta = async (senha: string) => {

        try {
        console.log("Deletando conta...")

        const apiDeletar = await fetch("http://localhost:3700/deletarconta", {
            method: "DELETE",
            credentials: "include",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                senha,
            })
        });

        const data = await apiDeletar.json();

        if(!apiDeletar.ok) {
            alert("Erro ao deletar conta: " + data.error);
            return;
        }


        navigate("/")

        console.log("Conta deletada com sucesso:", data); } catch (err) { 
        console.log("Ocorreu algum erro ao deletar conta", err);

        }
        
    }
    return (

        <Profile
        deletarconta={deletarconta}
        user={user}
        setUser={setUser}/>

    )
}