import SwiftUI

// ============================================================================
// 1. MODELO DE DATOS (Idéntico a nuestra estructura acordada)
// ============================================================================

struct Vuelo: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var trayecto: String          // "Ida", "Vuelta", "Escala"
    var origen: String            // Ej: "MAD"
    var destino: String           // Ej: "PRG"
    var fechaHoraSalida: Date
    var fechaHoraLlegada: Date
    var aerolinea: String
    var numeroVuelo: String
    var localizador: String
    var terminalPuerta: String
    var urlReserva: String
}

struct ItemChecklist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var texto: String
    var completado: Bool
    var asignadoA: String         // "Ambos", "Yo", "Tú"
}

struct Escapada: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var titulo: String
    var destino: String
    var fechaInicio: Date
    var fechaFin: Date
    var icono: String
    var esSorpresa: Bool
    var pistaSorpresa: String
    var recuerdo: String
    var vuelos: [Vuelo]
    var checklist: [ItemChecklist]
    var ideas: [String]
    
    var yaVivida: Bool {
        let finDelDia = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: fechaFin)) ?? fechaFin
        return Date() >= finDelDia
    }
    
    var progresoChecklist: Double {
        guard !checklist.isEmpty else { return 0 }
        let completados = checklist.filter { $0.completado }.count
        return Double(completados) / Double(checklist.count)
    }
}

// ============================================================================
// 2. GESTOR DE ESTADO Y PERSISTENCIA LOCAL (Listo para conectar Firebase/CloudKit)
// ============================================================================

@MainActor
class EscapadasStore: ObservableObject {
    @Published var escapadas: [Escapada] = [] {
        didSet { guardarEnDispositivo() }
    }
    @Published var codigoPareja: String = "VIAJE-2026"
    
    private let storageKey = "nuestras_escapadas_ios_v1"
    
    init() {
        cargarDesdeDispositivo()
        if escapadas.isEmpty {
            cargarEjemplosIniciales()
        }
    }
    
    var proximasEscapadas: [Escapada] {
        escapadas
            .filter { !$0.yaVivida }
            .sorted { $0.fechaInicio < $1.fechaInicio }
    }
    
    var escapadasPasadas: [Escapada] {
        escapadas
            .filter { $0.yaVivida }
            .sorted { $0.fechaInicio > $1.fechaInicio }
    }
    
    func agregarEscapada(_ nueva: Escapada) {
        escapadas.append(nueva)
    }
    
    func actualizarEscapada(_ actualizada: Escapada) {
        if let idx = escapadas.firstIndex(where: { $0.id == actualizada.id }) {
            escapadas[idx] = actualizada
        }
    }
    
    func eliminarEscapada(_ escapada: Escapada) {
        escapadas.removeAll { $0.id == escapada.id }
    }
    
    private func guardarEnDispositivo() {
        if let encoded = try? JSONEncoder().encode(escapadas) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func cargarDesdeDispositivo() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Escapada].self, from: data) {
            escapadas = decoded
        }
    }
    
    func cargarEjemplosIniciales() {
        let hoy = Date()
        let salidaPraga = Calendar.current.date(byAdding: .day, value: 18, to: hoy) ?? hoy
        let vueltaPraga = Calendar.current.date(byAdding: .day, value: 22, to: hoy) ?? hoy
        let fechaSorpresa = Calendar.current.date(byAdding: .day, value: 45, to: hoy) ?? hoy
        let fechaPasada = Calendar.current.date(byAdding: .day, value: -25, to: hoy) ?? hoy
        
        escapadas = [
            Escapada(
                titulo: "Escapada de invierno",
                destino: "Praga y montañas",
                fechaInicio: salidaPraga,
                fechaFin: vueltaPraga,
                icono: "✈️",
                esSorpresa: false,
                pistaSorpresa: "",
                recuerdo: "",
                vuelos: [
                    Vuelo(
                        trayecto: "Ida",
                        origen: "MAD",
                        destino: "PRG",
                        fechaHoraSalida: salidaPraga,
                        fechaHoraLlegada: Calendar.current.date(byAdding: .hour, value: 3, to: salidaPraga) ?? salidaPraga,
                        aerolinea: "Iberia",
                        numeroVuelo: "IB3140",
                        localizador: "K8M9LP",
                        terminalPuerta: "Terminal 4",
                        urlReserva: "https://www.iberia.com/es/gestion-reservas/"
                    ),
                    Vuelo(
                        trayecto: "Vuelta",
                        origen: "KRK",
                        destino: "MAD",
                        fechaHoraSalida: vueltaPraga,
                        fechaHoraLlegada: Calendar.current.date(byAdding: .hour, value: 3, to: vueltaPraga) ?? vueltaPraga,
                        aerolinea: "Ryanair",
                        numeroVuelo: "FR2418",
                        localizador: "X9P2TR",
                        terminalPuerta: "",
                        urlReserva: "https://www.ryanair.com"
                    )
                ],
                checklist: [
                    ItemChecklist(texto: "DNI / Pasaportes en vigor", completado: true, asignadoA: "Ambos"),
                    ItemChecklist(texto: "Ropa térmica y guantes", completado: true, asignadoA: "Ambos"),
                    ItemChecklist(texto: "Baterías portátiles", completado: false, asignadoA: "Yo")
                ],
                ideas: ["Puente de Carlos al amanecer", "Probar trdelník caliente"]
            ),
            Escapada(
                titulo: "Fin de semana secreto",
                destino: "Cabaña en el Valle del Jerte",
                fechaInicio: fechaSorpresa,
                fechaFin: Calendar.current.date(byAdding: .day, value: 2, to: fechaSorpresa) ?? fechaSorpresa,
                icono: "🎁",
                esSorpresa: true,
                pistaSorpresa: "Trae botas de montaña y ganas de desconectar.",
                recuerdo: "",
                vuelos: [],
                checklist: [
                    ItemChecklist(texto: "Botas de trekking", completado: false, asignadoA: "Ambos")
                ],
                ideas: ["Ruta de las cascadas"]
            ),
            Escapada(
                titulo: "Escapada rural y vino",
                destino: "Brihuega",
                fechaInicio: fechaPasada,
                fechaFin: Calendar.current.date(byAdding: .day, value: 2, to: fechaPasada) ?? fechaPasada,
                icono: "🍷",
                esSorpresa: false,
                pistaSorpresa: "",
                recuerdo: "Nos encantó cenar en la plaza y pasear tranquilos sin prisas.",
                vuelos: [],
                checklist: [],
                ideas: []
            )
        ]
    }
}

// ============================================================================
// 3. PUNTO DE ENTRADA DE LA APP iOS
// ============================================================================

@main
struct NuestrasEscapadasApp: App {
    @StateObject private var store = EscapadasStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Color(red: 0.88, green: 0.43, blue: 0.33)) // Terracota cálido
        }
    }
}

// ============================================================================
// 4. PANTALLA PRINCIPAL CON PESTAÑAS NATIVAS DE iOS
// ============================================================================

struct ContentView: View {
    @EnvironmentObject var store: EscapadasStore
    @State private var mostrandoNuevaEscapada = false
    @State private var mostrandoSyncPareja = false
    
    var body: some View {
        TabView {
            // Pestaña 1: Próximas escapadas
            NavigationStack {
                ProximasView(mostrandoNuevaEscapada: $mostrandoNuevaEscapada)
                    .navigationTitle("Nuestras Escapadas")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                mostrandoSyncPareja = true
                            } label: {
                                Label(store.codigoPareja, systemImage: "heart.circle.fill")
                                    .font(.caption.bold())
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                mostrandoNuevaEscapada = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                        }
                    }
            }
            .tabItem {
                Label("Próximas", systemImage: "calendar")
            }
            
            // Pestaña 2: Historial ya vivido
            NavigationStack {
                YaVividoView()
                    .navigationTitle("Ya vivido")
            }
            .tabItem {
                Label("Ya vivido", systemImage: "heart.fill")
            }
        }
        .sheet(isPresented: $mostrandoNuevaEscapada) {
            NuevaEscapadaSheet()
        }
        .sheet(isPresented: $mostrandoSyncPareja) {
            SyncParejaSheet()
        }
    }
}

// ============================================================================
// 5. VISTA DE PRÓXIMAS ESCAPADAS + CUENTA ATRÁS EN VIVO
// ============================================================================

struct ProximasView: View {
    @EnvironmentObject var store: EscapadasStore
    @Binding var mostrandoNuevaEscapada: Bool
    @State private var espiarSorpresaHero = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let hero = store.proximasEscapadas.first {
                    NavigationLink(value: hero) {
                        HeroCountdownCard(escapada: hero, espiar: $espiarSorpresaHero)
                    }
                    .buttonStyle(.plain)
                    
                    let siguientes = Array(store.proximasEscapadas.dropFirst())
                    if !siguientes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EN EL HORIZONTE")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            
                            ForEach(siguientes) { esc in
                                NavigationLink(value: esc) {
                                    EscapadaRowCard(escapada: esc)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("Sin escapadas próximas", systemImage: "airplane")
                    } description: {
                        Text("Añade vuestro próximo viaje o plan de fin de semana.")
                    } actions: {
                        Button("Crear primer plan") {
                            mostrandoNuevaEscapada = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationDestination(for: Escapada.self) { escapada in
            DetalleEscapadaView(escapadaId: escapada.id)
        }
    }
}

struct HeroCountdownCard: View {
    let escapada: Escapada
    @Binding var espiar: Bool
    
    var body: some View {
        let oculto = escapada.esSorpresa && !espiar
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Text(escapada.icono)
                    .font(.system(size: 34))
                    .frame(width: 58, height: 58)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRÓXIMA PARADA")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    
                    Text(escapada.titulo)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            
            // Bloque Destino o Sorpresa
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(oculto ? "🤫 Destino sorpresa oculto" : "📍 \(escapada.destino)")
                        .font(.subheadline.bold())
                    Text(oculto ? (escapada.pistaSorpresa.isEmpty ? "¡Prepárate!" : escapada.pistaSorpresa) : escapada.fechaInicio.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if escapada.esSorpresa {
                    Button(oculto ? "Espiar" : "Ocultar") {
                        espiar.toggle()
                    }
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                } else if !escapada.vuelos.isEmpty {
                    Label("\(escapada.vuelos.count)", systemImage: "airplane")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            // Contador en tiempo real usando TimelineView nativo de iOS
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let diff = max(0, escapada.fechaInicio.timeIntervalSince(context.date))
                let dias = Int(diff) / 86400
                let horas = (Int(diff) % 86400) / 3600
                let mins = (Int(diff) % 3600) / 60
                
                HStack(spacing: 10) {
                    ContadorBox(valor: "\(dias)", etiqueta: "Días", destacado: true)
                    ContadorBox(valor: String(format: "%02d", horas), etiqueta: "Horas", destacado: false)
                    ContadorBox(valor: String(format: "%02d", mins), etiqueta: "Minutos", destacado: false)
                }
            }
            
            // Progreso Checklist
            VStack(spacing: 6) {
                HStack {
                    Text("Preparativos listos")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    let listos = escapada.checklist.filter { $0.completado }.count
                    Text("\(listos)/\(escapada.checklist.count)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                ProgressView(value: escapada.progresoChecklist)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

struct ContadorBox: View {
    let valor: String
    let etiqueta: String
    let destacado: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(destacado ? .white : .primary)
            Text(etiqueta)
                .font(.caption2)
                .foregroundStyle(destacado ? .white.opacity(0.9) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(destacado ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct EscapadaRowCard: View {
    let escapada: Escapada
    
    var body: some View {
        let dias = max(0, Calendar.current.dateComponents([.day], from: Date(), to: escapada.fechaInicio).day ?? 0)
        
        HStack(spacing: 14) {
            Text(escapada.icono)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(escapada.titulo)
                    .font(.headline)
                Text(escapada.esSorpresa ? "🎁 Plan sorpresa" : escapada.destino)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(dias == 0 ? "¡Hoy!" : "En \(dias)d")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// ============================================================================
// 6. FICHA DETALLE DE ESCAPADA (Vuelos, Checklist, Ideas y Recuerdo)
// ============================================================================

struct DetalleEscapadaView: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaId: UUID
    
    @State private var nuevoItemTexto = ""
    @State private var nuevoItemAsignado = "Ambos"
    @State private var nuevaIdeaTexto = ""
    @State private var mostrandoAgregarVuelo = false
    
    private var escapadaIndex: Int? {
        store.escapadas.firstIndex(where: { $0.id == escapadaId })
    }
    
    var body: some View {
        if let idx = escapadaIndex {
            let escapada = store.escapadas[idx]
            
            List {
                // Cabecera y modo sorpresa
                Section {
                    HStack(spacing: 14) {
                        Text(escapada.icono)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(escapada.titulo)
                                .font(.title3.bold())
                            Text("📍 \(escapada.destino)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("🗓️ \(escapada.fechaInicio.formatted(date: .abbreviated, time: .omitted)) – \(escapada.fechaFin.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle("🎁 Modo plan sorpresa", isOn: $store.escapadas[idx].esSorpresa)
                    
                    if escapada.esSorpresa {
                        TextField("Pista para portada...", text: $store.escapadas[idx].pistaSorpresa)
                    }
                }
                
                // Sección Vuelos
                Section {
                    if escapada.vuelos.isEmpty {
                        Text("Sin vuelos añadidos todavía")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(escapada.vuelos) { vuelo in
                            VueloCardView(vuelo: vuelo)
                        }
                        .onDelete { offsets in
                            store.escapadas[idx].vuelos.remove(atOffsets: offsets)
                        }
                    }
                    
                    Button {
                        mostrandoAgregarVuelo = true
                    } label: {
                        Label("Añadir vuelo", systemImage: "airplane.departure")
                    }
                } header: {
                    Text("Vuelos y billetes")
                }
                
                // Sección Checklist
                Section {
                    HStack {
                        TextField("Añadir cosa...", text: $nuevoItemTexto)
                        Picker("", selection: $nuevoItemAsignado) {
                            Text("Ambos").tag("Ambos")
                            Text("Yo").tag("Yo")
                            Text("Tú").tag("Tú")
                        }
                        .labelsHidden()
                        Button {
                            guard !nuevoItemTexto.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            store.escapadas[idx].checklist.append(
                                ItemChecklist(texto: nuevoItemTexto, completado: false, asignadoA: nuevoItemAsignado)
                            )
                            nuevoItemTexto = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                    
                    ForEach($store.escapadas[idx].checklist) { $item in
                        HStack {
                            Button {
                                item.completado.toggle()
                            } label: {
                                Image(systemName: item.completado ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.completado ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.texto)
                                .strikethrough(item.completado)
                                .foregroundStyle(item.completado ? .secondary : .primary)
                            
                            Spacer()
                            
                            Text(item.asignadoA)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                    }
                    .onDelete { offsets in
                        store.escapadas[idx].checklist.remove(atOffsets: offsets)
                    }
                } header: {
                    Text("Checklist compartida")
                }
                
                // Sección Ideas
                Section {
                    HStack {
                        TextField("Restaurante, sitio o enlace...", text: $nuevaIdeaTexto)
                        Button {
                            guard !nuevaIdeaTexto.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            store.escapadas[idx].ideas.append(nuevaIdeaTexto)
                            nuevaIdeaTexto = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                    
                    ForEach(escapada.ideas, id: \.self) { idea in
                        if let url = URL(string: idea), idea.hasPrefix("http") {
                            Link(destination: url) {
                                Label(idea, systemImage: "link")
                                    .lineLimit(1)
                            }
                        } else {
                            Text("💡 \(idea)")
                        }
                    }
                    .onDelete { offsets in
                        store.escapadas[idx].ideas.remove(atOffsets: offsets)
                    }
                } header: {
                    Text("Ideas y enlaces")
                }
                
                // Sección Recuerdo
                Section {
                    TextEditor(text: $store.escapadas[idx].recuerdo)
                        .frame(minHeight: 80)
                } header: {
                    Text("Nuestro recuerdo")
                }
                
                Section {
                    Button("Eliminar escapada", role: .destructive) {
                        store.eliminarEscapada(escapada)
                        dismiss()
                    }
                }
            }
            .navigationTitle(escapada.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $mostrandoAgregarVuelo) {
                AgregarVueloSheet(escapadaIndex: idx)
            }
        }
    }
}

struct VueloCardView: View {
    let vuelo: Vuelo
    @State private var copiado = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(vuelo.trayecto.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                
                Text("\(vuelo.aerolinea) · \(vuelo.numeroVuelo)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(vuelo.origen)
                        .font(.title2.bold())
                    Text(vuelo.fechaHoraSalida.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Image(systemName: "airplane")
                    .foregroundStyle(Color.accentColor)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(vuelo.destino)
                        .font(.title2.bold())
                    Text(vuelo.fechaHoraLlegada.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                }
            }
            
            HStack {
                Button {
                    UIPasteboard.general.string = vuelo.localizador
                    copiado = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiado = false }
                } label: {
                    HStack {
                        Text("Loc: \(vuelo.localizador)")
                            .font(.caption.monospaced().bold())
                        Image(systemName: copiado ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if let url = URL(string: vuelo.urlReserva), !vuelo.urlReserva.isEmpty {
                    Link(destination: url) {
                        Label("Check-in", systemImage: "arrow.up.right.square")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// ============================================================================
// 7. FORMULARIOS MODALES (Nueva Escapada, Añadir Vuelo, Sincronizar)
// ============================================================================

struct NuevaEscapadaSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    
    @State private var titulo = ""
    @State private var destino = ""
    @State private var fechaInicio = Date()
    @State private var fechaFin = Date()
    @State private var icono = "✈️"
    @State private var esSorpresa = false
    @State private var pista = ""
    
    let iconos = ["✈️", "🏔️", "🏖️", "🌿", "🍷", "🚗", "🎁", "🏙️"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Icono") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(iconos, id: \.self) { em in
                                Text(em)
                                    .font(.title)
                                    .padding(8)
                                    .background(icono == em ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture { icono = em }
                            }
                        }
                    }
                }
                
                Section("Detalles del plan") {
                    TextField("Nombre del plan", text: $titulo)
                    TextField("Destino", text: $destino)
                    DatePicker("Fecha ida", selection: $fechaInicio, displayedComponents: .date)
                    DatePicker("Fecha vuelta", selection: $fechaFin, in: fechaInicio..., displayedComponents: .date)
                }
                
                Section {
                    Toggle("🎁 Modo plan sorpresa", isOn: $esSorpresa)
                    if esSorpresa {
                        TextField("Pista para tu pareja", text: $pista)
                    }
                }
            }
            .navigationTitle("Nueva escapada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let nueva = Escapada(
                            titulo: titulo,
                            destino: destino,
                            fechaInicio: fechaInicio,
                            fechaFin: fechaFin,
                            icono: icono,
                            esSorpresa: esSorpresa,
                            pistaSorpresa: pista,
                            recuerdo: "",
                            vuelos: [],
                            checklist: [ItemChecklist(texto: "Revisar documentación", completado: false, asignadoA: "Ambos")],
                            ideas: []
                        )
                        store.agregarEscapada(nueva)
                        dismiss()
                    }
                    .disabled(titulo.isEmpty || destino.isEmpty)
                }
            }
        }
    }
}

struct AgregarVueloSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaIndex: Int
    
    @State private var numeroVuelo = ""
    @State private var urlReserva = ""
    @State private var trayecto = "Ida"
    @State private var origen = ""
    @State private var destino = ""
    @State private var aerolinea = ""
    @State private var localizador = ""
    @State private var salida = Date()
    @State private var llegada = Date()
    @State private var terminal = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Asistente de aviación") {
                    TextField("URL de reserva (opcional)", text: $urlReserva)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    HStack {
                        TextField("Nº vuelo (ej: IB3140)", text: $numeroVuelo)
                            .autocapitalization(.allCharacters)
                        Button("Autocompletar") {
                            autocompletarVuelo()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Section("Datos del billete") {
                    Picker("Trayecto", selection: $trayecto) {
                        Text("Ida").tag("Ida")
                        Text("Vuelta").tag("Vuelta")
                        Text("Escala").tag("Escala")
                    }
                    TextField("Origen (ej: MAD)", text: $origen)
                        .autocapitalization(.allCharacters)
                    TextField("Destino (ej: PRG)", text: $destino)
                        .autocapitalization(.allCharacters)
                    TextField("Aerolínea", text: $aerolinea)
                    TextField("Localizador", text: $localizador)
                        .autocapitalization(.allCharacters)
                    DatePicker("Salida", selection: $salida)
                    DatePicker("Llegada", selection: $llegada)
                    TextField("Terminal / Puerta", text: $terminal)
                }
            }
            .navigationTitle("Añadir vuelo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let vuelo = Vuelo(
                            trayecto: trayecto,
                            origen: origen.uppercased(),
                            destino: destino.uppercased(),
                            fechaHoraSalida: salida,
                            fechaHoraLlegada: llegada,
                            aerolinea: aerolinea,
                            numeroVuelo: numeroVuelo.uppercased(),
                            localizador: localizador.uppercased(),
                            terminalPuerta: terminal,
                            urlReserva: urlReserva
                        )
                        store.escapadas[escapadaIndex].vuelos.append(vuelo)
                        dismiss()
                    }
                    .disabled(origen.isEmpty || destino.isEmpty || localizador.isEmpty)
                }
            }
        }
    }
    
    private func autocompletarVuelo() {
        let code = numeroVuelo.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if code == "IB3140" {
            aerolinea = "Iberia"
            origen = "MAD"
            destino = "PRG"
            terminal = "Terminal 4"
        } else if code == "FR2418" {
            trayecto = "Vuelta"
            aerolinea = "Ryanair"
            origen = "KRK"
            destino = "MAD"
        } else if code == "VY1002" {
            aerolinea = "Vueling"
            origen = "BCN"
            destino = "FCO"
            terminal = "Terminal 1"
        }
    }
}

struct YaVividoView: View {
    @EnvironmentObject var store: EscapadasStore
    
    var body: some View {
        List {
            if store.escapadasPasadas.isEmpty {
                ContentUnavailableView("Aún no hay recuerdos", systemImage: "photo.on.rectangle.angled")
            } else {
                ForEach(store.escapadasPasadas) { esc in
                    NavigationLink(value: esc) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(esc.icono) \(esc.titulo)")
                                    .font(.headline)
                                Spacer()
                                Text(esc.fechaInicio.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !esc.recuerdo.isEmpty {
                                Text("\"\(esc.recuerdo)\"")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationDestination(for: Escapada.self) { esc in
            DetalleEscapadaView(escapadaId: esc.id)
        }
    }
}

struct SyncParejaSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Código compartido de pareja") {
                    TextField("Código", text: $store.codigoPareja)
                        .font(.headline.monospaced())
                        .autocapitalization(.allCharacters)
                    Text("Usa este mismo código en ambos iPhones cuando conectes iCloud / CloudKit o Firebase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sincronización")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
