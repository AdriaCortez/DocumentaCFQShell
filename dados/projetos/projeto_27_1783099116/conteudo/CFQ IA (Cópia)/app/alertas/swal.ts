
import Swal from "sweetalert2";

export const ConfirmarDelete = Swal.mixin({
  customClass: {
    confirmButton: "btn btn-success",
    cancelButton: "btn btn-danger"
  }
});

export const ConfirmarAviso = Swal.mixin({
  customClass: {
    confirmButton: "btn btn-success"
  }
});

export async function simDeletar (nome: string) {

const confirmar = await ConfirmarDelete.fire({
  title: `Você quer realmente deletar o cadastro "${nome}"?`, //entre crase para que o ts reconheça o nome
  text: "Essa ação não poderá ser desfeita!",
  icon: "warning",
  showCancelButton: true,
  confirmButtonText: "Sim, deletar",
  cancelButtonText: "Cancelar",
  reverseButtons: true
})

return confirmar.isConfirmed

}
export async function aviso(text: string) {

  const aviso = await ConfirmarAviso.fire({  
    title: 'Atenção!',
    text: "O Dalton está em sua versão BETA (1.1). Algumas funcionalidades estão em desenvolvimento, e a IA ainda está sendo treinada para responder melhor suas questões! Parte das falhas que você pode enfrentar são erros ao clicar em botões (apesar de ser um pouco raro), respostas imprecisas ou não contínuas e lentidão nas respostas mais longas.Em caso de dúvidas, feedbacks e semelhantes, informar à Gerência de Tecnologia da informação e comunicação (GETIC)",
    icon: 'info',
    confirmButtonText: 'Ok, entendi!'
  })



  return aviso.isConfirmed
}