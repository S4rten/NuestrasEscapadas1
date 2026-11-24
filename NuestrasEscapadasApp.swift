// ... existing code ...
struct NuevaEscapadaSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    
    @State private var titulo = ""
    @State private var destino = ""
    @State private var icono = "✈️"
    @State private var fechaInicio = Date().addingTimeInterval(86400 * 14)
    @State private var fechaFin = Date().addingTimeInterval(86400 * 17)
    @State private var esSorpresa = false
    @State private var pistaSorpresa = ""
    @State private var diasRevelarAntes = 0
    
    @State private var tieneVuelos = false
    @State private var localizadorVuelo = ""
    @State private var numeroVuelo = ""
    @State private var horaSalidaVuelo = Date()
    @State private var origenVuelo = ""
    @State private var destinoVuelo = ""
    @State private var aerolineaVuelo = ""
    @State private var urlReservaVuelo = ""
    @State private var buscandoVuelo = false
    @State private var estadoAutocompletado = ""
    
    @State private var tieneTrenes = false
    @State private var operadoraTren = "Renfe"
    @State private var origenTren = ""
    @State private var destinoTren = ""
    @State private var localizadorTren = ""
    
    let iconos = ["✈️", "🏔️", "🏖️", "🍷", "🎁", "🚗", "🏙️", "🌿", "🍝", "🚂"]
// ... existing code ...
                        Vuelo(
                            trayecto: "Ida",
                            origen: origenVuelo.isEmpty ? "MAD" : origenVuelo.uppercased(),
                            destino: destinoVuelo.isEmpty ? "DEST" : destinoVuelo.uppercased(),
                            fechaHoraSalida: fechaSalidaCompleta,
                            fechaHoraLlegada: fechaSalidaCompleta.addingTimeInterval(7200),
                            aerolinea: aerolineaVuelo.isEmpty ? "Aerolínea" : aerolineaVuelo,
                            numeroVuelo: numeroVuelo.uppercased(),
                            localizador: localizadorVuelo.uppercased(),
                            terminalPuerta: "",
                            urlReserva: urlReservaVuelo
                        )
                    ] : []
                    
                    let trenesIniciales: [TrenViaje] = (tieneTrenes && (!origenTren.isEmpty || !destinoTren.isEmpty || !localizadorTren.isEmpty)) ? [
                        TrenViaje(
                            trayecto: "Ida",
                            operadora: operadoraTren,
                            estacionOrigen: origenTren.isEmpty ? "Origen" : origenTren,
                            estacionDestino: destinoTren.isEmpty ? destino : destinoTren,
                            fechaHoraSalida: fechaInicio,
                            fechaHoraLlegada: fechaInicio.addingTimeInterval(9000),
                            localizador: localizadorTren.uppercased()
                        )
                    ] : []
                    
                    let nueva = Escapada(
                        titulo: titulo,
                        destino: destino,
                        fechaInicio: fechaInicio,
                        fechaFin: fechaFin,
                        icono: icono,
                        tieneVuelos: tieneVuelos,
                        tieneTrenes: tieneTrenes,
                        esSorpresa: esSorpresa,
                        pistaSorpresa: pistaSorpresa,
                        diasRevelarSorpresaAntes: diasRevelarAntes,
                        recuerdo: "",
                        vuelos: vuelosIniciales,
                        trenes: trenesIniciales,
                        checklist: [
                            ItemChecklist(texto: "DNI / Pasaportes", completado: false, asignadoA: "Ambos"),
                            ItemChecklist(texto: "Cargadores", completado: false, asignadoA: "Ambos")
                        ],
                        itinerario: [],
                        ideas: []
                    )
                    store.agregarEscapada(nueva)
                    dismiss()
// ... existing code ...