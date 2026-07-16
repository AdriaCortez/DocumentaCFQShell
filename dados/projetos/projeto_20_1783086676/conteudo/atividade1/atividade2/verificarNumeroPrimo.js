function verificarNumeroPrimo(n) {

    var i = 3
    const limite = Math.sqrt(n)

    if (n <= 1) {
        console.log("Não é número primo")
        return false; //se for menor que um

    } else if (n === 2  ) {
        console.log("É número primo")
        return true; //2 é um primo par

    } else if(n % 2 === 0) {
        console.log('Não é primo')
        return false; //outros numeros pares não são primos
    }

    for (i; i <= limite; i+=2) {
        if( n % i === 0) {
            return false;
        } //verifica os divisores
    }

    return true;

}

verificarNumeroPrimo(0); //false
verificarNumeroPrimo(1); //false
verificarNumeroPrimo(2); //true
verificarNumeroPrimo(3); //true
verificarNumeroPrimo(7); //true
verificarNumeroPrimo(83); //true
verificarNumeroPrimo(100); //false
verificarNumeroPrimo(991); //true
verificarNumeroPrimo(104729); //true
verificarNumeroPrimo(14348907); //false
