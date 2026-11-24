// ... existing code ...
struct AlojamientoInfo: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var nombre: String = ""
    var direccion: String = ""
    var horaCheckIn: String = "15:00"
    var horaCheckOut: String = "11:00"
    var codigoReserva: String = ""
    var urlReserva: String = ""
    
    var tieneDatos: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty ||
        !direccion.trimmingCharacters(in: .whitespaces).isEmpty ||
        !codigoReserva.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    init(
        id: UUID = UUID(),
        nombre: String = "",
        direccion: String = "",
        horaCheckIn: String = "15:00",
        horaCheckOut: String = "11:00",
        codigoReserva: String = "",
        urlReserva: String = ""
    ) {
        self.id = id
        self.nombre = nombre
        self.direccion = direccion
        self.horaCheckIn = horaCheckIn
        self.horaCheckOut = horaCheckOut
        self.codigoReserva = codigoReserva
        self.urlReserva = urlReserva
    }
    
    enum CodingKeys: String, CodingKey {
        case id, nombre, direccion, horaCheckIn, horaCheckOut, codigoReserva, urlReserva
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        direccion = try c.decodeIfPresent(String.self, forKey: .direccion) ?? ""
        horaCheckIn = try c.decodeIfPresent(String.self, forKey: .horaCheckIn) ?? "15:00"
        horaCheckOut = try c.decodeIfPresent(String.self, forKey: .horaCheckOut) ?? "11:00"
        codigoReserva = try c.decodeIfPresent(String.self, forKey: .codigoReserva) ?? ""
        urlReserva = try c.decodeIfPresent(String.self, forKey: .urlReserva) ?? ""
    }
}
// ... existing code ...
    var momentoFavorito: String = ""
    var valoracion: ValoracionViaje = ValoracionViaje()
    var alojamiento: AlojamientoInfo = AlojamientoInfo()
    var alojamientos: [AlojamientoInfo] = []
    var gastos: [GastoViaje] = []
    var retosFoto: [RetoFotografico] = []
// ... existing code ...
        recuerdo: String,
        momentoFavorito: String = "",
        valoracion: ValoracionViaje = ValoracionViaje(),
        alojamiento: AlojamientoInfo = AlojamientoInfo(),
        alojamientos: [AlojamientoInfo] = [],
        gastos: [GastoViaje] = [],
        retosFoto: [RetoFotografico] = [],
// ... existing code ...
        self.recuerdo = recuerdo
        self.momentoFavorito = momentoFavorito
        self.valoracion = valoracion
        self.alojamiento = alojamiento
        if !alojamientos.isEmpty {
            self.alojamientos = alojamientos
        } else if alojamiento.tieneDatos {
            self.alojamientos = [alojamiento]
        } else {
            self.alojamientos = []
        }
        self.gastos = gastos
        self.retosFoto = retosFoto
// ... existing code ...
    enum CodingKeys: String, CodingKey {
        case id, titulo, destino, fechaInicio, fechaFin, icono, tieneVuelos, tieneTrenes, esSorpresa, pistaSorpresa
        case diasRevelarSorpresaAntes, recuerdo, momentoFavorito, valoracion, alojamiento, alojamientos, gastos
        case retosFoto, documentos, vuelos, trenes, checklist, itinerario, ideas
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        titulo = try c.decode(String.self, forKey: .titulo)
        destino = try c.decode(String.self, forKey: .destino)
        fechaInicio = try c.decode(Date.self, forKey: .fechaInicio)
        fechaFin = try c.decode(Date.self, forKey: .fechaFin)
        icono = try c.decodeIfPresent(String.self, forKey: .icono) ?? "✈️"
        vuelos = try c.decodeIfPresent([Vuelo].self, forKey: .vuelos) ?? []
        trenes = try c.decodeIfPresent([TrenViaje].self, forKey: .trenes) ?? []
        tieneVuelos = try c.decodeIfPresent(Bool.self, forKey: .tieneVuelos) ?? !vuelos.isEmpty
        tieneTrenes = try c.decodeIfPresent(Bool.self, forKey: .tieneTrenes) ?? !trenes.isEmpty
        esSorpresa = try c.decodeIfPresent(Bool.self, forKey: .esSorpresa) ?? false
        pistaSorpresa = try c.decodeIfPresent(String.self, forKey: .pistaSorpresa) ?? ""
        diasRevelarSorpresaAntes = try c.decodeIfPresent(Int.self, forKey: .diasRevelarSorpresaAntes) ?? 0
        recuerdo = try c.decodeIfPresent(String.self, forKey: .recuerdo) ?? ""
        momentoFavorito = try c.decodeIfPresent(String.self, forKey: .momentoFavorito) ?? ""
        valoracion = try c.decodeIfPresent(ValoracionViaje.self, forKey: .valoracion) ?? ValoracionViaje()
        let alojUnico = try c.decodeIfPresent(AlojamientoInfo.self, forKey: .alojamiento) ?? AlojamientoInfo()
        self.alojamiento = alojUnico
        let listaAloj = try c.decodeIfPresent([AlojamientoInfo].self, forKey: .alojamientos) ?? []
        if !listaAloj.isEmpty {
            self.alojamientos = listaAloj
        } else if alojUnico.tieneDatos {
            self.alojamientos = [alojUnico]
        } else {
            self.alojamientos = []
        }
        gastos = try c.decodeIfPresent([GastoViaje].self, forKey: .gastos) ?? []
        retosFoto = try c.decodeIfPresent([RetoFotografico].self, forKey: .retosFoto) ?? []
// ... existing code ...
    @State private var mostrandoAgregarVuelo = false
    @State private var mostrandoAgregarTren = false
    @State private var mostrandoNuevoAlojamiento = false
    @State private var alojamientoEnEdicion: AlojamientoInfo? = nil
    @State private var mostrandoAgregarGasto = false
    @State private var mostrandoAgregarDocumento = false
    @State private var mostrandoRuleta = false
    @State private var documentoSeleccionado: DocumentoBoveda? = nil
    @State private var retoParaFoto: RetoFotografico? = nil
    @State private var itemPickerReto: PhotosPickerItem? = nil
    @State private var retoConFotoEnVisor: RetoFotografico? = nil
    @State private var alojamientoCopiadoId: UUID? = nil
    @State private var previsionClima: [PrevisionDia] = []
    @State private var cargandoClima = false
// ... existing code ...
        .sheet(isPresented: $mostrandoAgregarTren) {
            if let esc = escapadaActual {
                AgregarTrenSheet(escapada: esc)
            }
        }
        .sheet(isPresented: $mostrandoNuevoAlojamiento) {
            if let esc = escapadaActual {
                EditarAlojamientoSheet(escapada: esc, alojamientoExistente: nil)
            }
        }
        .sheet(item: $alojamientoEnEdicion) { aloj in
            if let esc = escapadaActual {
                EditarAlojamientoSheet(escapada: esc, alojamientoExistente: aloj)
            }
        }
        .sheet(isPresented: $mostrandoAgregarGasto) {
// ... existing code ...
                Section {
                    ForEach(escapada.alojamientos) { aloj in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(aloj.nombre.isEmpty ? "Alojamiento reservado" : aloj.nombre)
                                        .font(.headline)
                                    if !aloj.direccion.isEmpty {
                                        Text("📍 \(aloj.direccion)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("🕒 Check-in \(aloj.horaCheckIn) · Check-out \(aloj.horaCheckOut)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Editar") {
                                    alojamientoEnEdicion = aloj
                                }
                                .font(.caption.bold())
                            }
                            
                            HStack(spacing: 8) {
                                if !aloj.codigoReserva.isEmpty {
                                    Button {
                                        UIPasteboard.general.string = aloj.codigoReserva
                                        alojamientoCopiadoId = aloj.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            if alojamientoCopiadoId == aloj.id {
                                                alojamientoCopiadoId = nil
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text("Ref: \(aloj.codigoReserva)")
                                                .font(.caption.monospaced().bold())
                                            Image(systemName: alojamientoCopiadoId == aloj.id ? "checkmark" : "doc.on.doc")
                                                .font(.caption2)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                let queryMapa = (aloj.direccion.isEmpty ? "\(aloj.nombre) \(escapada.destino)" : aloj.direccion)
                                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let mapUrl = URL(string: "http://maps.apple.com/?q=\(queryMapa)"), !queryMapa.isEmpty {
                                    Link(destination: mapUrl) {
                                        Label("Cómo llegar", systemImage: "map.fill")
                                            .font(.caption.bold())
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        var copia = escapada
                        copia.alojamientos.remove(atOffsets: offsets)
                        copia.alojamiento = copia.alojamientos.first ?? AlojamientoInfo()
                        store.actualizarEscapada(copia)
                    }
                    
                    Button {
                        mostrandoNuevoAlojamiento = true
                    } label: {
                        Label(escapada.alojamientos.isEmpty ? "Añadir hotel o apartamento" : "Añadir otro alojamiento", systemImage: "bed.double.fill")
                    }
                } header: {
                    Text("🏨 Alojamientos (\(escapada.alojamientos.count))")
                }
            }
// ... existing code ...
                ForEach(escapada.gastos) { gasto in
                    HStack(spacing: 10) {
                        Text(iconoCategoriaGasto(gasto.categoria))
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gasto.concepto)
                                .font(.subheadline.weight(.medium))
                            Text("\(gasto.categoria) · Pagó \(gasto.pagadoPor)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let orig = gasto.importeOriginal,
                           let mon = gasto.monedaOriginal,
                           mon.uppercased() != "EUR" {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.2f %@", orig, mon.uppercased()))
                                    .font(.subheadline.bold().monospacedDigit())
                                Text(String(format: "≈ %.2f €", gasto.importe))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(String(format: "%.2f €", gasto.importe))
                                .font(.subheadline.bold().monospacedDigit())
                        }
                    }
                }
                .onDelete { offsets in
// ... existing code ...
                Section {
                    Toggle("✈️ ¿Este viaje incluye vuelos?", isOn: $tieneVuelos)
                    
                    if tieneVuelos {
                        TextField("Código de reserva / localizador", text: $localizadorVuelo)
                            .autocapitalization(.allCharacters)
                        TextField("Nº de vuelo (ej: IB3140)", text: $numeroVuelo)
                            .autocapitalization(.allCharacters)
                        DatePicker("Hora de salida (ida)", selection: $horaSalidaVuelo, displayedComponents: .hourAndMinute)
                        
                        Button {
                            Task { await autocompletarDesdeWeb() }
                        } label: {
                            HStack {
                                if buscandoVuelo { ProgressView() }
                                else { Image(systemName: "globe.europe.africa.fill") }
                                Text(buscandoVuelo ? "Buscando vuelo..." : "Autocompletar origen y destino")
                                    .font(.subheadline.bold())
                            }
                        }
                        
                        if !estadoAutocompletado.isEmpty {
                            Text(estadoAutocompletado)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        
                        HStack {
                            TextField("Origen (ej: MAD)", text: $origenVuelo)
                                .autocapitalization(.allCharacters)
                            TextField("Destino (ej: PRG)", text: $destinoVuelo)
                                .autocapitalization(.allCharacters)
                        }
                        TextField("Aerolínea (ej: Iberia)", text: $aerolineaVuelo)
                        TextField("Enlace de reserva / check-in", text: $urlReservaVuelo)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                } header: {
                    Text("Vuelos")
                }
                
                Section {
                    Toggle("🚆 ¿Este viaje incluye trenes?", isOn: $tieneTrenes)
                    
                    if tieneTrenes {
                        Picker("Operadora (España)", selection: $operadoraTren) {
                            Text("Renfe").tag("Renfe")
                            Text("Iryo").tag("Iryo")
                            Text("Ouigo").tag("Ouigo")
                            Text("Alvia / Avlo").tag("Alvia / Avlo")
                        }
                        HStack(spacing: 8) {
                            if let u1 = URL(string: "https://www.renfe.com") {
                                Link("Renfe", destination: u1).font(.caption.bold()).buttonStyle(.bordered)
                            }
                            if let u2 = URL(string: "https://iryo.eu") {
                                Link("Iryo", destination: u2).font(.caption.bold()).buttonStyle(.bordered)
                            }
                            if let u3 = URL(string: "https://www.ouigo.com/es") {
                                Link("Ouigo", destination: u3).font(.caption.bold()).buttonStyle(.bordered)
                            }
                        }
                        TextField("Estación origen", text: $origenTren)
                        TextField("Estación destino", text: $destinoTren)
                        TextField("Localizador del tren (opcional)", text: $localizadorTren)
                            .autocapitalization(.allCharacters)
                    }
                } header: {
                    Text("Trenes")
                }
                
                Section {
// ... existing code ...
struct EditarAlojamientoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    let alojamientoExistente: AlojamientoInfo?
    
    @State private var nombre = ""
    @State private var direccion = ""
    @State private var horaCheckIn = "15:00"
    @State private var horaCheckOut = "11:00"
    @State private var codigoReserva = ""
    @State private var urlReserva = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del alojamiento") {
                    TextField("Nombre del hotel o apartamento", text: $nombre)
                    TextField("Dirección exacta o zona", text: $direccion)
                }
                
                Section("Horarios y reserva") {
                    TextField("Hora Check-in", text: $horaCheckIn)
                    TextField("Hora Check-out", text: $horaCheckOut)
                    TextField("Código / Localizador de reserva", text: $codigoReserva)
                        .autocapitalization(.allCharacters)
                    TextField("Enlace de la reserva", text: $urlReserva)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle(alojamientoExistente == nil ? "Nuevo alojamiento" : "Editar alojamiento")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let aloj = alojamientoExistente {
                    nombre = aloj.nombre
                    direccion = aloj.direccion
                    horaCheckIn = aloj.horaCheckIn
                    horaCheckOut = aloj.horaCheckOut
                    codigoReserva = aloj.codigoReserva
                    urlReserva = aloj.urlReserva
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var urlLimpia = urlReserva.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !urlLimpia.isEmpty && !urlLimpia.hasPrefix("http") {
                            urlLimpia = "https://" + urlLimpia
                        }
                        let nuevoAloj = AlojamientoInfo(
                            id: alojamientoExistente?.id ?? UUID(),
                            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                            direccion: direccion.trimmingCharacters(in: .whitespacesAndNewlines),
                            horaCheckIn: horaCheckIn.trimmingCharacters(in: .whitespacesAndNewlines),
                            horaCheckOut: horaCheckOut.trimmingCharacters(in: .whitespacesAndNewlines),
                            codigoReserva: codigoReserva.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            urlReserva: urlLimpia
                        )
                        var copia = escapada
                        if let existente = alojamientoExistente,
                           let idx = copia.alojamientos.firstIndex(where: { $0.id == existente.id }) {
                            copia.alojamientos[idx] = nuevoAloj
                        } else {
                            copia.alojamientos.append(nuevoAloj)
                        }
                        copia.alojamiento = copia.alojamientos.first ?? AlojamientoInfo()
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty && direccion.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
// ... existing code ...