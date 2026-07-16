import express from 'express';
import cors from "cors";
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import cookieParser from 'cookie-parser';

dotenv.config();

const app = express(); 
const port = 3700;
const uri = process.env.MONGO_URI_TEST;
const access = process.env.ACCESS_TOKEN_TEST;

app.use(express.json()); 
app.use(cookieParser());
app.use(cors({
  origin: [
    "http://localhost:5173",
    "http://localhost:3700",
    "http://localhost"
  ],
  credentials: true,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"]
}));

app.use(express.urlencoded({ extended: true }));

const { Schema, model } = mongoose;

const credenciaisSchema = new Schema({
  email: {
    type: String,
    required: true,
    unique: true
  },
  senha: {
    type: String,
    required: true,
    select: false
  }, //Não é pro Mongoose trazer o campo senha
  nome: { 
    type: String,
    required: true
  }
}); 

const Credenciais = model('Credenciais', credenciaisSchema);

//Isso aqui é um middleware de verificação que irá receber os cookies para substituir a verificação no header.

function auth (req, res, next){
  const token = req.cookies.auth; //autenticação do token é feita com cookies

  if(!token) {
    return res.status(401).json({ error: "não autenticado" })
  } //não teve cookie? Não autentica

  try { 
    
    const decoded = jwt.verify(token, access); 

    req.userId = decoded.id;
    next(); //next passa para o próximo middleware

  } catch (err) {
    return res.status(401).json({ error: "Token inválido"});
  }
}

app.get('/st', auth, async (req, res) => { //eu não me lembro porque coloquei st, ignorem - Dia 26 de março: "É SUBMITED TOKEN"
  try {

    const user = await Credenciais
      .findById(req.userId)
      .select("-senha"); //acha as credenciais cadastradas pelo id e não devolve a senha no frontend junto com as outras informações para evitar vazamentos.

    if (!user) {
      return res.status(404).json({ error: "Usuário não encontrado" });
    } 

    return res.json(user);

  } catch (err) {

      console.error("Erro detalhado do JWT:", err.name, err.message);
      return res.status(401).json({ error: err.message });
  } 
}); //o st é caso a autênticação for obrigatória. Serve bem pro login


app.post('/subscribe', async (req, res) => {
  try {
    const { nome, email, senha } = req.body; //pega nome, email e senha do front

    if (!nome || !email || !senha) {
      return res.status(400).json({
        error: "As credenciais completas são obrigatórias"
      }); //Se não tiver nenhum vai retornar um status 400
    } 


    const hash = await bcrypt.hash(senha, 10);

    const subs = await Credenciais.create({
      nome,
      email,
      senha: hash
    }); //Cria um novo usuário e hasheia a senha através do bcrypt

    return res.status(201).json({
      message: "Cadastro salvo!",
      id: subs._id
    });

  } catch (err) {

    if(err.code === 11000) {
      return res.status(11000).json({ error: "Conta já cadastrada "})
    }
    
    console.error("ERRO NO SUBSCRIBE:", err);
    return res.status(500).json({ 
      message: "Erro interno", 
      error: err.message 
    });
  }
}); //Subscribe serve pra validar o token e garantir o que usuário existe


app.post('/auth-login', async (req, res) => {
  try {
    console.log("Verificando credenciais...");

    const { email, senha } = req.body;

        if (!email || !senha) {
          return res.status(400).json({
            error: "Email e senha são obrigatórios"
          });
        }

        const user = await Credenciais
          .findOne({ email }) //busca através do email do usuário (já que muitos usuários podem ter o mesmo nome)
          .select("+senha"); /*Depois de buscar pelo email, como a senha foi hasheada pelo bcrypt, ele só vai forçar uma 
          comparação entre a senha colocada pelo usuário e o hash gerado pelo bcrypt.*/

        if (!user) {
          return res.status(403).json({
            error: "Cadastro inválido! Verifique seu e-mail ou senha"
          });
        }

    const SenhaCorreta = await bcrypt.compare(senha, user.senha); 

        if (!SenhaCorreta) {
          return res.status(403).json({ 
            error: "Senha inválida!" 
          });
        }

    const token = jwt.sign(
      { id: user._id, email: user.email },
      access,
      { expiresIn: "20m" }
    ); //gera o token

    res.cookie("auth", token, { //auth é o nome do cookie e token é o JWT gerado
      httpOnly: true, //quer dizer que o cookie não é acessado por Javascript (só o backend acessa)
      secure: false, //Pro cookie salvar no localhost
      sameSite: "lax", //envia cookie e bloqueia que o site receba uma requisição falsa
      maxAge: 20 * 60 * 1000 //tempo de vida do cookie (20 minutos - ou 1200000 milisegundos). ELe tem que bater com o expiresIn do JWT)
    }) 

    return res.json({ ok: true })

  } catch (err) {
    console.error("ERRO NO /auth-login:", err);
    return res.status(500).json({ 
      error: "Erro! Cheque usuário e senha ou verifique com o admin da página" 
    });
  } //se der um crash na rota, retorna um erro 500
});

app.post("/logout", (req, res) => {
  res.clearCookie("auth", {
    httpOnly: true,
    secure: false, //isso aqui so funciona se o cookie criado tambem tiver secure: false
    sameSite: "lax",
  })

  return res.json({ message: "Logout realizado com sucesso" })
})


app.put('/trocarsenha', auth, async (req, res) => {
  try {

    const {  senhaatual, novasenha, confirmarsenha } = req.body; 

    if (!senhaatual || !novasenha || !confirmarsenha) {
      return res.status(400).json({ error: "Preencha todos os campos" });
    }

    if (novasenha !== confirmarsenha) {
      return res.status(400).json({ error: "As senhas não coincidem" });
    }

    const user = await Credenciais .findById(req.userId).select("+senha"); 

    if(!user) {
      return res.status(404).json({ error: "Ops. Usuário não encontrado" });
    }

    const correto = await bcrypt.compare(senhaatual, user.senha); 

    if (!correto) {
      return res.status(403).json({ error: "Senha atual incorreta" });
    }

    const hashnovasenha = await bcrypt.hash(novasenha, 10);

    user.senha = hashnovasenha; 

    await user.save(); //save é necessario pro mongoose atualizar a senha no banco de dados

    return res.json({ message: "Senha alterada com sucesso!" });

  } catch (err) {
    console.log("Erro na rota /trocarsenha, verifique o servidor. Código de erro:", err);
    return res.status(500).json({ error: "Erro interno no servidor" });
  }

});

app.delete('/deletarconta', auth, async (req, res) => {
  try {
    
    const { senha } = req.body;

    if(!senha) {
      return res.status(400).json({ error: "Senha é obrigatória"})
    }

    const user = await Credenciais.findById(req.userId).select("+senha");

    if (!user) {
      return res.status(404).json({ error: "Usuário não encontrado" });
    }

    const SenhaCorreta = await bcrypt.compare(senha, user.senha);

    if (!SenhaCorreta) {
      return res.status(403).json({ error: "Senha incorreta" });
    }

    await Credenciais.findByIdAndDelete(req.userId);

    res.clearCookie("auth");

    return res.json({ message: "Conta deletada com sucesso!" });

  } catch (err) {
    console.error("Erro ao tentar deletar conta:", err);
    return res.status(500).json({ error: "Erro interno no servidor" });
  }

})

async function start() {
    try { 
      await mongoose.connect(uri, { 
        serverSelectionTimeoutMS: 15000,
        heartbeatFrequencyMS: 2000
      }); 
      
      console.log("Mongoose conectado com sucesso!");

      app.listen(port, '0.0.0.0', () => {
        console.log(`Express na porta ${port}`);
      }); 

    } catch (err) {
      console.error("Erro ao conectar ao MongoDB:", err);
    } 
}

start();

/*Aqui tivemos inscrição e autênticação com muita atenção aos campos de senha pra que ela não fosse vazada nem no Mongo, nem no front,
e, se Deus quiser, nem no back. Isso evita falhas de segurança e vazamentos, mas ainda é necessário testar caminhos de segurança mais
robustos - como autênticação de dois fatores e outras maneiras de acessp, mas isso é mais razoável futuramente quando o código estiver
funcional para uma ampla rede de pessoas. 

*/