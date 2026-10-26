// =====================================================================
// Painel de Crédito e Inadimplência no Brasil - Power Query (M)
// Fonte: API de Dados Abertos do Banco Central (SGS)
// Como usar: Power BI > Obter dados > Consulta nula > Editor Avançado
// Cole tudo abaixo e renomeie a consulta para: fSeries
// =====================================================================
let
    // 1) Função que busca uma série do SGS pelo código
    //    RelativePath + Query evitam erro de "fonte dinâmica" ao publicar no Power BI Service
    // Busca a série na API. Em caso de falha, tenta de novo (até 3 vezes) sem usar cache.
    fnBuscar = (codigo as number, tentativa as number) as list =>
        let
            Resposta = try Function.InvokeAfter(
                () => Json.Document(
                    Web.Contents(
                        "https://api.bcb.gov.br",
                        [
                            RelativePath = "dados/serie/bcdata.sgs." & Number.ToText(codigo) & "/dados",
                            Query = [
                                formato = "json",
                                dataInicial = "01/01/2015",
                                dataFinal = Date.ToText(Date.From(DateTime.LocalNow()), [Format = "dd/MM/yyyy"])
                            ],
                            Headers = [Accept = "application/json"],
                            IsRetry = tentativa > 1
                        ]
                    )
                ),
                #duration(0, 0, 0, tentativa)
            ),
            Resultado =
                if not Resposta[HasError] then Resposta[Value]
                else if tentativa < 3 then @fnBuscar(codigo, tentativa + 1)
                else {}   // depois de 3 falhas, devolve lista vazia e o painel segue sem essa série
        in
            Resultado,

    fnSerieBCB = (codigo as number) as table =>
        let
            Lista  = fnBuscar(codigo, 1),
            Tabela = if List.IsEmpty(Lista)
                     then #table(type table [data = date, valor = number], {})
                     else Table.TransformColumns(
                         Table.FromRecords(Lista),
                         {
                             {"data",  each Date.FromText(_, [Format = "dd/MM/yyyy", Culture = "pt-BR"]), type date},
                             {"valor", each Number.FromText(_, "en-US"), type number}
                         }
                     )
        in
            Tabela,

    // 2) Catálogo das séries usadas no painel
    Series = #table(
        type table [Codigo = Int64.Type, Indicador = text, Grupo = text, Unidade = text],
        {
            {21082, "Inadimplência - Total",                         "Inadimplência",          "%"},
            {21084, "Inadimplência - Pessoas físicas",               "Inadimplência",          "%"},
            {21083, "Inadimplência - Pessoas jurídicas",             "Inadimplência",          "%"},
            {21112, "Inadimplência PF - Recursos livres",            "Inadimplência por modalidade", "%"},
            {21129, "Inadimplência PF - Cartão de crédito",          "Inadimplência por modalidade", "%"},
            {21114, "Inadimplência PF - Crédito pessoal não consignado", "Inadimplência por modalidade", "%"},
            {21119, "Inadimplência PF - Consignado",                 "Inadimplência por modalidade", "%"},
            {21123, "Inadimplência PF - Aquisição de bens",          "Inadimplência por modalidade", "%"},
            {20541, "Saldo da carteira de crédito - PF",             "Volume de crédito",      "R$ milhões"},
            {20716, "Taxa média de juros - PF",                      "Juros",                  "% a.a."},
            {25479, "Taxa média mensal de juros - Cartão de crédito PF", "Juros",              "% a.m."},
            {4189,  "Selic acumulada no mês (anualizada)",           "Juros",                  "% a.a."},
            {29037, "Endividamento das famílias (% da renda 12m)",   "Endividamento",          "%"}
        }
    ),

    // 3) Busca cada série e empilha tudo em formato longo
    ComDados   = Table.AddColumn(Series, "Dados", each fnSerieBCB([Codigo])),
    Expandido  = Table.ExpandTableColumn(ComDados, "Dados", {"data", "valor"}, {"Data", "Valor"}),
    Tipos      = Table.TransformColumnTypes(Expandido, {{"Data", type date}, {"Valor", type number}})
in
    Tipos
