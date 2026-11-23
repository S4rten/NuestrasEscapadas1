import SwiftUI
import FirebaseCore
import FirebaseFirestore

// ============================================================================
// 1. MODELO DE DATOS (Compatible con Codable de Firestore)
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

struct ActividadDia: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var diaIndex: Int             // 1, 2, 3... según los días del viaje
    var nombreSitio: String
    var urlSitio: String
}

struct ValoracionViaje: Codable, Hashable {
    var experienciaCiudad: Int = 0
    var museosCultura: Int = 0
    var gastronomia: Int = 0
    var alojamientoDescanso: Int = 0
    var momentosJuntos: Int = 0
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
    var momentoFavorito: String = ""
    var valoracion: ValoracionViaje = ValoracionViaje()
    var vuelos: [Vuelo]
    var checklist: [ItemChecklist]
    var itinerario: [ActividadDia] = []
    var ideas: [String]
    
    var yaVivida: Bool {
        let finDelDia = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: fechaFin)) ?? fechaFin
        return Date() >= finDelDia
    }
    
    var sorpresaDesbloqueada: Bool {
        let inicioDelDia = Calendar.current.startOfDay(for: fechaInicio)
        return Date() >= inicioDelDia
    }
    
    var totalDias: Int {
        let inicio = Calendar.current.startOfDay(for: fechaInicio)
        let fin = Calendar.current.startOfDay(for: fechaFin)
        let diff = Calendar.current.dateComponents([.day], from: inicio, to: fin).day ?? 0
        return max(1, diff + 1)
    }
    
    func fechaParaDia(_ diaIndex: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: diaIndex - 1, to: fechaInicio) ?? fechaInicio
    }
    
    var progresoChecklist: Double {
        guard !checklist.isEmpty else { return 0 }
        let completados = checklist.filter { $0.completado }.count
        return Double(completados) / Double(checklist.count)
    }
    
    // Decodificador tolerante para escapadas antiguas guardadas en Firestore sin los nuevos campos
    init(
        id: UUID = UUID(),
        titulo: String,
        destino: String,
        fechaInicio: Date,
        fechaFin: Date,
        icono: String,
        esSorpresa: Bool,
        pistaSorpresa: String,
        recuerdo: String,
        momentoFavorito: String = "",
        valoracion: ValoracionViaje = ValoracionViaje(),
        vuelos: [Vuelo],
        checklist: [ItemChecklist],
        itinerario: [ActividadDia] = [],
        ideas: [String]
    ) {
        self.id = id
        self.titulo = titulo
        self.destino = destino
        self.fechaInicio = fechaInicio
        self.fechaFin = fechaFin
        self.icono = icono
        self.esSorpresa = esSorpresa
        self.pistaSorpresa = pistaSorpresa
        self.recuerdo = recuerdo
        self.momentoFavorito = momentoFavorito
        self.valoracion = valoracion
        self.vuelos = vuelos
        self.checklist = checklist
        self.itinerario = itinerario
        self.ideas = ideas
    }
    
    enum CodingKeys: String, CodingKey {
        case id, titulo, destino, fechaInicio, fechaFin, icono, esSorpresa, pistaSorpresa
        case recuerdo, momentoFavorito, valoracion, vuelos, checklist, itinerario, ideas
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        titulo = try c.decode(String.self, forKey: .titulo)
        destino = try c.decode(String.self, forKey: .destino)
        fechaInicio = try c.decode(Date.self, forKey: .fechaInicio)
        fechaFin = try c.decode(Date.self, forKey: .fechaFin)
        icono = try c.decodeIfPresent(String.self, forKey: .icono) ?? "✈️"
        esSorpresa = try c.decodeIfPresent(Bool.self, forKey: .esSorpresa) ?? false
        pistaSorpresa = try c.decodeIfPresent(String.self, forKey: .pistaSorpresa) ?? ""
        recuerdo = try c.decodeIfPresent(String.self, forKey: .recuerdo) ?? ""
        momentoFavorito = try c.decodeIfPresent(String.self, forKey: .momentoFavorito) ?? ""
        valoracion = try c.decodeIfPresent(ValoracionViaje.self, forKey: .valoracion) ?? ValoracionViaje()
        vuelos = try c.decodeIfPresent([Vuelo].self, forKey: .vuelos) ?? []
        checklist = try c.decodeIfPresent([ItemChecklist].self, forKey: .checklist) ?? []
        itinerario = try c.decodeIfPresent([ActividadDia].self, forKey: .itinerario) ?? []
        ideas = try c.decodeIfPresent([String].self, forKey: .ideas) ?? []
    }
}

// ============================================================================
// 2. GESTOR DE ESTADO Y SINCRONIZACIÓN EN TIEMPO REAL CON FIRESTORE
// ============================================================================

@MainActor
class EscapadasStore: ObservableObject {
    @Published var escapadas: [Escapada] = []
    @Published var codigoPareja: String {
        didSet {
            UserDefaults.standard.set(codigoPareja, forKey: "codigo_pareja_ios")
        }
    }
    @Published var estadoNube: String = "Conectando..."
    @Published var firebaseActivo: Bool = false
    
    private var db: Firestore?
    private var listener: ListenerRegistration?
    private let localBackupKey = "nuestras_escapadas_backup_v2"
    private var primeraCargaSala = true
    
    init() {
        let guardado = UserDefaults.standard.string(forKey: "codigo_pareja_ios") ?? "VIAJE-2026"
        self.codigoPareja = guardado
        cargarCopiaLocal()
        configurarFirebase()
    }
    
    deinit {
        listener?.remove()
    }
    
    private func configurarFirebase() {
        // Comprobamos que GoogleService-Info.plist esté incluido en la app
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            estadoNube = "Modo local (falta GoogleService-Info.plist)"
            firebaseActivo = false
            if escapadas.isEmpty { cargarEjemplosIniciales(subirANube: false) }
            return
        }
        
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        db = Firestore.firestore()
        firebaseActivo = true
        conectarASala(codigo: codigoPareja)
    }
    
    func conectarASala(codigo: String) {
        let limpio = codigo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "-")
        
        guard !limpio.isEmpty else { return }
        codigoPareja = limpio
        
        guard let db = db else { return }
        
        listener?.remove()
        primeraCargaSala = true
        estadoNube = "Conectando..."
        
        let coleccion = db.collection("parejas").document(limpio).collection("escapadas")
        
        listener = coleccion.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.estadoNube = "Error: \(error.localizedDescription)"
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            self.estadoNube = "En vivo"
            
            let remotas: [Escapada] = documents.compactMap { doc in
                try? doc.data(as: Escapada.self)
            }
            
            // Si es una sala nueva vacía, cargamos ejemplos iniciales una sola vez
            if self.primeraCargaSala && remotas.isEmpty {
                self.primeraCargaSala = false
                self.cargarEjemplosIniciales(subirANube: true)
                return
            }
            
            self.primeraCargaSala = false
            self.escapadas = remotas
            self.guardarCopiaLocal()
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
        guardarCopiaLocal()
        guardarEnFirestore(nueva)
    }
    
    func actualizarEscapada(_ actualizada: Escapada) {
        if let idx = escapadas.firstIndex(where: { $0.id == actualizada.id }) {
            escapadas[idx] = actualizada
            guardarCopiaLocal()
            guardarEnFirestore(actualizada)
        }
    }
    
    func eliminarEscapada(_ escapada: Escapada) {
        escapadas.removeAll { $0.id == escapada.id }
        guardarCopiaLocal()
        
        guard let db = db else { return }
        db.collection("parejas")
            .document(codigoPareja)
            .collection("escapadas")
            .document(escapada.id.uuidString)
            .delete()
    }
    
    private func guardarEnFirestore(_ escapada: Escapada) {
        guard let db = db else { return }
        do {
            try db.collection("parejas")
                .document(codigoPareja)
                .collection("escapadas")
                .document(escapada.id.uuidString)
                .setData(from: escapada, merge: true)
        } catch {
            estadoNube = "Error al guardar"
        }
    }
    
    private func guardarCopiaLocal() {
        if let encoded = try? JSONEncoder().encode(escapadas) {
            UserDefaults.standard.set(encoded, forKey: localBackupKey)
        }
    }
    
    private func cargarCopiaLocal() {
        if let data = UserDefaults.standard.data(forKey: localBackupKey),
           let decoded = try? JSONDecoder().decode([Escapada].self, from: data) {
            escapadas = decoded
        }
    }
    
    func cargarEjemplosIniciales(subirANube: Bool = true) {
        let hoy = Date()
        let salidaPraga = Calendar.current.date(byAdding: .day, value: 18, to: hoy) ?? hoy
        let vueltaPraga = Calendar.current.date(byAdding: .day, value: 22, to: hoy) ?? hoy
        let fechaSorpresa = Calendar.current.date(byAdding: .day, value: 45, to: hoy) ?? hoy
        let fechaPasada = Calendar.current.date(byAdding: .day, value: -25, to: hoy) ?? hoy
        
        let iniciales = [
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
                itinerario: [
                    ActividadDia(diaIndex: 1, nombreSitio: "Puente de Carlos y Ciudad Vieja", urlSitio: "https://www.prague.eu"),
                    ActividadDia(diaIndex: 2, nombreSitio: "Castillo de Praga y Callejón del Oro", urlSitio: "https://www.hrad.cz"),
                    ActividadDia(diaIndex: 3, nombreSitio: "Museo Nacional y cena tradicional", urlSitio: "")
                ],
                ideas: ["Probar trdelník caliente", "Mirador de Letná al atardecer"]
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
                momentoFavorito: "El atardecer entre los campos con una copa de vino local.",
                valoracion: ValoracionViaje(
                    experienciaCiudad: 5,
                    museosCultura: 4,
                    gastronomia: 5,
                    alojamientoDescanso: 5,
                    momentosJuntos: 5
                ),
                vuelos: [],
                checklist: [],
                ideas: []
            )
        ]
        
        escapadas = iniciales
        guardarCopiaLocal()
        if subirANube {
            for esc in iniciales {
                guardarEnFirestore(esc)
            }
        }
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
                .tint(Color(red: 0.88, green: 0.43, blue: 0.33))
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
            NavigationStack {
                ProximasView(mostrandoNuevaEscapada: $mostrandoNuevaEscapada)
                    .navigationTitle("Nuestras Escapadas")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                mostrandoSyncPareja = true
                            } label: {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(store.estadoNube == "En vivo" ? Color.green : Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text(store.codigoPareja)
                                        .font(.caption.bold().monospaced())
                                }
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let hero = store.proximasEscapadas.first {
                    NavigationLink(value: hero) {
                        HeroCountdownCard(escapada: hero)
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
    
    var body: some View {
        let oculto = escapada.esSorpresa && !escapada.sorpresaDesbloqueada
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Text(escapada.icono)
                    .font(.system(size: 34))
                    .frame(width: 58, height: 58)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(oculto ? "SORPRESA BLOQUEADA" : "PRÓXIMA PARADA")
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
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(oculto ? "🔒 Destino oculto hasta el día del viaje" : "📍 \(escapada.destino)")
                        .font(.subheadline.bold())
                    Text(oculto ? (escapada.pistaSorpresa.isEmpty ? "Pista: ¡Prepárate para disfrutar!" : "💡 Pista: \(escapada.pistaSorpresa)") : escapada.fechaInicio.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if oculto {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .padding(8)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Circle())
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
        let oculto = escapada.esSorpresa && !escapada.sorpresaDesbloqueada
        
        HStack(spacing: 14) {
            Text(escapada.icono)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(escapada.titulo)
                    .font(.headline)
                Text(oculto ? "🔒 \(escapada.pistaSorpresa.isEmpty ? "Destino secreto" : escapada.pistaSorpresa)" : escapada.destino)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
// 6. FICHA DETALLE DE ESCAPADA (Sincroniza cada cambio en Firestore)
// ============================================================================

struct DetalleEscapadaView: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaId: UUID
    
    @State private var diaSeleccionado: Int = 1
    @State private var nuevoSitioNombre = ""
    @State private var nuevoSitioURL = ""
    @State private var nuevoItemTexto = ""
    @State private var nuevoItemAsignado = "Ambos"
    @State private var nuevaIdeaTexto = ""
    @State private var mostrandoAgregarVuelo = false
    
    private var escapadaActual: Escapada? {
        store.escapadas.first(where: { $0.id == escapadaId })
    }
    
    var body: some View {
        if let escapada = escapadaActual {
            let sorpresaBloqueada = escapada.esSorpresa && !escapada.sorpresaDesbloqueada
            
            List {
                // Cabecera y modo sorpresa
                Section {
                    HStack(spacing: 14) {
                        Text(escapada.icono)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(escapada.titulo)
                                .font(.title3.bold())
                            if sorpresaBloqueada {
                                Text("🔒 Destino secreto hasta el \(escapada.fechaInicio.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                Text("💡 Pista: \(escapada.pistaSorpresa.isEmpty ? "Sin pista todavía" : escapada.pistaSorpresa)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("📍 \(escapada.destino)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("🗓️ \(escapada.fechaInicio.formatted(date: .abbreviated, time: .omitted)) – \(escapada.fechaFin.formatted(date: .abbreviated, time: .omitted)) (\(escapada.totalDias) \(escapada.totalDias == 1 ? "día" : "días"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Toggle("🎁 Modo plan sorpresa", isOn: Binding(
                        get: { escapada.esSorpresa },
                        set: { nuevoValor in
                            var copia = escapada
                            copia.esSorpresa = nuevoValor
                            store.actualizarEscapada(copia)
                        }
                    ))
                    
                    if escapada.esSorpresa {
                        TextField("Pista para tu pareja...", text: Binding(
                            get: { escapada.pistaSorpresa },
                            set: { nuevaPista in
                                var copia = escapada
                                copia.pistaSorpresa = nuevaPista
                                store.actualizarEscapada(copia)
                            }
                        ))
                    }
                }
                
                // Sección Plan por Días (oculta si la sorpresa sigue bloqueada)
                if !sorpresaBloqueada {
                    Section {
                        if escapada.totalDias > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(1...escapada.totalDias, id: \.self) { dia in
                                        let fechaDia = escapada.fechaParaDia(dia)
                                        let activo = diaSeleccionado == dia
                                        Button {
                                            diaSeleccionado = dia
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text("Día \(dia)")
                                                    .font(.caption.bold())
                                                Text(fechaDia.formatted(.dateTime.day().month(.abbreviated)))
                                                    .font(.caption2)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(activo ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
                                            .foregroundStyle(activo ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Formulario para añadir sitio y URL al día seleccionado
                        VStack(spacing: 8) {
                            TextField("Nombre del sitio o plan (ej: Museo del Prado)", text: $nuevoSitioNombre)
                            HStack {
                                TextField("URL opcional (ej: https://...)", text: $nuevoSitioURL)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .font(.caption)
                                
                                Button {
                                    let nombre = nuevoSitioNombre.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !nombre.isEmpty else { return }
                                    var urlLimpia = nuevoSitioURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !urlLimpia.isEmpty && !urlLimpia.hasPrefix("http") {
                                        urlLimpia = "https://" + urlLimpia
                                    }
                                    var copia = escapada
                                    copia.itinerario.append(
                                        ActividadDia(
                                            diaIndex: diaSeleccionado,
                                            nombreSitio: nombre,
                                            urlSitio: urlLimpia
                                        )
                                    )
                                    store.actualizarEscapada(copia)
                                    nuevoSitioNombre = ""
                                    nuevoSitioURL = ""
                                } label: {
                                    Label("Añadir", systemImage: "plus.circle.fill")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(nuevoSitioNombre.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Lista de sitios del día seleccionado
                        let actividadesDelDia = escapada.itinerario.filter { $0.diaIndex == diaSeleccionado }
                        if actividadesDelDia.isEmpty {
                            Text("Aún no hay sitios planeados para el Día \(diaSeleccionado).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(actividadesDelDia) { act in
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(Color.accentColor)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(act.nombreSitio)
                                            .font(.subheadline.weight(.medium))
                                        if let url = URL(string: act.urlSitio), !act.urlSitio.isEmpty {
                                            Link(destination: url) {
                                                Label(act.urlSitio.replacingOccurrences(of: "https://", with: ""), systemImage: "safari")
                                                    .font(.caption)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .onDelete { offsets in
                                let idsABorrar = offsets.map { actividadesDelDia[$0].id }
                                var copia = escapada
                                copia.itinerario.removeAll { idsABorrar.contains($0.id) }
                                store.actualizarEscapada(copia)
                            }
                        }
                    } header: {
                        Text(escapada.totalDias > 1 ? "Itinerario por días (Día \(diaSeleccionado))" : "Plan del día y sitios")
                    }
                    
                    // Sección Vuelos
                    Section {
                        if escapada.vuelos.isEmpty {
                            Text("Sin vuelos añadidos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(escapada.vuelos) { vuelo in
                                VueloCardView(vuelo: vuelo)
                            }
                            .onDelete { offsets in
                                var copia = escapada
                                copia.vuelos.remove(atOffsets: offsets)
                                store.actualizarEscapada(copia)
                            }
                        }
                        
                        Button {
                            mostrandoAgregarVuelo = true
                        } label: {
                            Label("Añadir vuelo", systemImage: "airplane.circle.fill")
                        }
                    } header: {
                        Text("Vuelos y billetes")
                    }
                } else {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "eye.slash.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                            Text("El itinerario, destino y vuelos permanecerán ocultos automáticamente hasta el día \(escapada.fechaInicio.formatted(date: .long, time: .omitted)) para mantener la sorpresa.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("Sorpresa protegida")
                    }
                }
                
                // Sección Checklist (con diseño amplio en dos líneas para evitar que se solapen los botones)
                Section {
                    VStack(spacing: 10) {
                        TextField("¿Qué hay que llevar o preparar?", text: $nuevoItemTexto)
                            .textFieldStyle(.plain)
                        
                        HStack(spacing: 12) {
                            Picker("Asignado a", selection: $nuevoItemAsignado) {
                                Text("Ambos").tag("Ambos")
                                Text("Yo").tag("Yo")
                                Text("Tú").tag("Tú")
                            }
                            .pickerStyle(.segmented)
                            
                            Button {
                                guard !nuevoItemTexto.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                var copia = escapada
                                copia.checklist.append(
                                    ItemChecklist(
                                        texto: nuevoItemTexto.trimmingCharacters(in: .whitespaces),
                                        completado: false,
                                        asignadoA: nuevoItemAsignado
                                    )
                                )
                                store.actualizarEscapada(copia)
                                nuevoItemTexto = ""
                            } label: {
                                Label("Añadir", systemImage: "plus.circle.fill")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(nuevoItemTexto.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    ForEach(escapada.checklist) { item in
                        HStack {
                            Image(systemName: item.completado ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.completado ? Color.accentColor : .secondary)
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            var copia = escapada
                            if let i = copia.checklist.firstIndex(where: { $0.id == item.id }) {
                                copia.checklist[i].completado.toggle()
                                store.actualizarEscapada(copia)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var copia = escapada
                        copia.checklist.remove(atOffsets: offsets)
                        store.actualizarEscapada(copia)
                    }
                } header: {
                    Text("Checklist compartida")
                }
                
                // Sección Ideas
                Section {
                    HStack {
                        TextField("Idea, restaurante o enlace...", text: $nuevaIdeaTexto)
                        Button {
                            guard !nuevaIdeaTexto.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            var copia = escapada
                            copia.ideas.append(nuevaIdeaTexto.trimmingCharacters(in: .whitespaces))
                            store.actualizarEscapada(copia)
                            nuevaIdeaTexto = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    
                    ForEach(Array(escapada.ideas.enumerated()), id: \.offset) { idx, idea in
                        if let url = URL(string: idea), idea.hasPrefix("http") {
                            Link(idea, destination: url)
                        } else {
                            Text(idea)
                        }
                    }
                    .onDelete { offsets in
                        var copia = escapada
                        copia.ideas.remove(atOffsets: offsets)
                        store.actualizarEscapada(copia)
                    }
                } header: {
                    Text("Notas rápidas e ideas")
                }
                
                // Sección Recuerdo Ampliada + Valoración (Solo visible cuando la escapada ya ha finalizado)
                if escapada.yaVivida {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Puntuación del viaje (1 a 5)")
                                .font(.subheadline.bold())
                            
                            FilaEstrellasView(
                                titulo: "🏙️ Experiencia de la ciudad",
                                puntuacion: Binding(
                                    get: { escapada.valoracion.experienciaCiudad },
                                    set: { val in
                                        var copia = escapada
                                        copia.valoracion.experienciaCiudad = val
                                        store.actualizarEscapada(copia)
                                    }
                                )
                            )
                            
                            FilaEstrellasView(
                                titulo: "🏛️ Museos y cultura",
                                puntuacion: Binding(
                                    get: { escapada.valoracion.museosCultura },
                                    set: { val in
                                        var copia = escapada
                                        copia.valoracion.museosCultura = val
                                        store.actualizarEscapada(copia)
                                    }
                                )
                            )
                            
                            FilaEstrellasView(
                                titulo: "🍽️ Gastronomía y cafés",
                                puntuacion: Binding(
                                    get: { escapada.valoracion.gastronomia },
                                    set: { val in
                                        var copia = escapada
                                        copia.valoracion.gastronomia = val
                                        store.actualizarEscapada(copia)
                                    }
                                )
                            )
                            
                            FilaEstrellasView(
                                titulo: "🛏️ Alojamiento y descanso",
                                puntuacion: Binding(
                                    get: { escapada.valoracion.alojamientoDescanso },
                                    set: { val in
                                        var copia = escapada
                                        copia.valoracion.alojamientoDescanso = val
                                        store.actualizarEscapada(copia)
                                    }
                                )
                            )
                            
                            FilaEstrellasView(
                                titulo: "💕 Plan y momentos juntos",
                                puntuacion: Binding(
                                    get: { escapada.valoracion.momentosJuntos },
                                    set: { val in
                                        var copia = escapada
                                        copia.valoracion.momentosJuntos = val
                                        store.actualizarEscapada(copia)
                                    }
                                )
                            )
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("✨ Nuestro momento favorito")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ZStack(alignment: .topLeading) {
                                if escapada.momentoFavorito.isEmpty {
                                    Text("Describe con calma ese instante especial del viaje...")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                                TextEditor(text: Binding(
                                    get: { escapada.momentoFavorito },
                                    set: { nuevoFav in
                                        var copia = escapada
                                        copia.momentoFavorito = nuevoFav
                                        store.actualizarEscapada(copia)
                                    }
                                ))
                                .frame(minHeight: 110)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("📝 Diario y anécdotas de la escapada")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextEditor(text: Binding(
                                get: { escapada.recuerdo },
                                set: { nuevoRecuerdo in
                                    var copia = escapada
                                    copia.recuerdo = nuevoRecuerdo
                                    store.actualizarEscapada(copia)
                                }
                            ))
                            .frame(minHeight: 140)
                        }
                    } header: {
                        HStack {
                            Text("Nuestro recuerdo y valoración")
                            Spacer()
                            Text("Aventura finalizada")
                                .font(.caption2.bold())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
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
            .onAppear {
                if diaSeleccionado > escapada.totalDias {
                    diaSeleccionado = 1
                }
            }
            .sheet(isPresented: $mostrandoAgregarVuelo) {
                AgregarVueloSheet(escapada: escapada)
            }
        }
    }
}

struct FilaEstrellasView: View {
    let titulo: String
    @Binding var puntuacion: Int
    
    var body: some View {
        HStack {
            Text(titulo)
                .font(.caption.weight(.medium))
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { estrella in
                    Button {
                        puntuacion = (puntuacion == estrella) ? 0 : estrella
                    } label: {
                        Image(systemName: estrella <= puntuacion ? "star.fill" : "star")
                            .font(.subheadline)
                            .foregroundStyle(estrella <= puntuacion ? Color.orange : Color.secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
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
    let escapada: Escapada
    
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
    @State private var mensajeAutocompletado = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Asistente automático por localizador, URL o vuelo") {
                    TextField("Localizador (ej: K8M9LP) - Autocompleta ruta", text: $localizador)
                        .autocapitalization(.allCharacters)
                        .onChange(of: localizador) { _, nuevoLoc in
                            autocompletarDesdeLocalizadorOUrl(locBruto: nuevoLoc, urlBruta: urlReserva)
                        }
                    
                    TextField("URL de reserva o check-in (opcional)", text: $urlReserva)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .onChange(of: urlReserva) { _, nuevaUrl in
                            autocompletarDesdeLocalizadorOUrl(locBruto: localizador, urlBruta: nuevaUrl)
                        }
                    
                    HStack {
                        TextField("Nº vuelo (ej: IB3140, VY1002)", text: $numeroVuelo)
                            .autocapitalization(.allCharacters)
                            .onChange(of: numeroVuelo) { _, nuevoValor in
                                autocompletarVuelo(codigoBruto: nuevoValor)
                            }
                        Button("Buscar") {
                            autocompletarDesdeLocalizadorOUrl(locBruto: localizador, urlBruta: urlReserva)
                            autocompletarVuelo(codigoBruto: numeroVuelo)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if !mensajeAutocompletado.isEmpty {
                        Text(mensajeAutocompletado)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Section("Datos del billete") {
                    Picker("Trayecto", selection: $trayecto) {
                        Text("Ida").tag("Ida")
                        Text("Vuelta").tag("Vuelta")
                        Text("Escala").tag("Escala")
                    }
                    .onChange(of: trayecto) { _, nuevoTrayecto in
                        actualizarOrigenDestinoPorDefecto(paraTrayecto: nuevoTrayecto)
                    }
                    TextField("Origen (ej: MAD)", text: $origen)
                        .autocapitalization(.allCharacters)
                    TextField("Destino (ej: PRG)", text: $destino)
                        .autocapitalization(.allCharacters)
                    TextField("Aerolínea", text: $aerolinea)
                    DatePicker("Salida", selection: $salida)
                    DatePicker("Llegada", selection: $llegada)
                    TextField("Terminal / Puerta", text: $terminal)
                }
            }
            .navigationTitle("Añadir vuelo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                salida = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: escapada.fechaInicio) ?? escapada.fechaInicio
                llegada = Calendar.current.date(byAdding: .hour, value: 2, to: salida) ?? salida
                actualizarOrigenDestinoPorDefecto(paraTrayecto: trayecto)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let locFinal = localizador.trimmingCharacters(in: .whitespaces).isEmpty ? "SIN-LOC" : localizador.uppercased()
                        let vuelo = Vuelo(
                            trayecto: trayecto,
                            origen: origen.uppercased(),
                            destino: destino.uppercased(),
                            fechaHoraSalida: salida,
                            fechaHoraLlegada: llegada,
                            aerolinea: aerolinea.isEmpty ? "Aerolínea" : aerolinea,
                            numeroVuelo: numeroVuelo.uppercased(),
                            localizador: locFinal,
                            terminalPuerta: terminal,
                            urlReserva: urlReserva
                        )
                        var copia = escapada
                        copia.vuelos.append(vuelo)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(origen.isEmpty || destino.isEmpty)
                }
            }
        }
    }
    
    private func iataDesdeTextoDestino(_ texto: String) -> String {
        let lower = texto.lowercased()
        let mapaCiudades: [(clave: String, iata: String)] = [
            ("praga", "PRG"), ("cracovia", "KRK"), ("varsovia", "WAW"),
            ("roma", "FCO"), ("milan", "MXP"), ("milán", "MXP"), ("venecia", "VCE"), ("napoles", "NAP"), ("nápoles", "NAP"),
            ("paris", "ORY"), ("parís", "ORY"), ("lyon", "LYS"), ("niza", "NCE"),
            ("londres", "LHR"), ("edimburgo", "EDI"), ("dublin", "DUB"), ("dublín", "DUB"),
            ("lisboa", "LIS"), ("oporto", "OPO"), ("faro", "FAO"),
            ("amsterdam", "AMS"), ("ámsterdam", "AMS"), ("bruselas", "BRU"),
            ("berlin", "BER"), ("berlín", "BER"), ("munich", "MUC"), ("múnich", "MUC"), ("frankfurt", "FRA"),
            ("viena", "VIE"), ("budapest", "BUD"), ("atenas", "ATH"),
            ("estambul", "IST"), ("marrakech", "RAK"), ("tenerife", "TFN"), ("gran canaria", "LPA"),
            ("mallorca", "PMI"), ("palma", "PMI"), ("ibiza", "IBZ"), ("menorca", "MAH"),
            ("barcelona", "BCN"), ("madrid", "MAD"), ("sevilla", "SVQ"), ("malaga", "AGP"), ("málaga", "AGP"), ("valencia", "VLC")
        ]
        for item in mapaCiudades {
            if lower.contains(item.clave) {
                return item.iata
            }
        }
        return ""
    }
    
    private func actualizarOrigenDestinoPorDefecto(paraTrayecto tr: String) {
        let iataDestinoViaje = iataDesdeTextoDestino(escapada.destino)
        if tr == "Vuelta" {
            if !iataDestinoViaje.isEmpty { origen = iataDestinoViaje }
            if destino.isEmpty || destino == iataDestinoViaje { destino = "MAD" }
            salida = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: escapada.fechaFin) ?? escapada.fechaFin
            llegada = Calendar.current.date(byAdding: .hour, value: 2, to: salida) ?? salida
        } else {
            if origen.isEmpty || origen == iataDestinoViaje { origen = "MAD" }
            if !iataDestinoViaje.isEmpty { destino = iataDestinoViaje }
            salida = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: escapada.fechaInicio) ?? escapada.fechaInicio
            llegada = Calendar.current.date(byAdding: .hour, value: 2, to: salida) ?? salida
        }
    }
    
    private func autocompletarDesdeLocalizadorOUrl(locBruto: String, urlBruta: String) {
        let loc = locBruto.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlLower = urlBruta.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Si pega URL de reserva, detecta aerolínea, parámetros (origin/dest/pnr) y rellena datos
        if !urlLower.isEmpty {
            if urlLower.contains("iberia") { aerolinea = "Iberia" }
            else if urlLower.contains("ryanair") { aerolinea = "Ryanair" }
            else if urlLower.contains("vueling") { aerolinea = "Vueling" }
            else if urlLower.contains("aireuropa") { aerolinea = "Air Europa" }
            else if urlLower.contains("easyjet") { aerolinea = "easyJet" }
            else if urlLower.contains("lufthansa") { aerolinea = "Lufthansa" }
            else if urlLower.contains("airfrance") { aerolinea = "Air France" }
            else if urlLower.contains("britishairways") { aerolinea = "British Airways" }
            else if urlLower.contains("flytap") { aerolinea = "TAP Air Portugal" }
            
            // Extraer códigos IATA de 3 letras si vienen en la URL (ej: MAD-PRG o origin=MAD&destination=PRG)
            let upperUrl = urlBruta.uppercased()
            if let regex = try? NSRegularExpression(pattern: "(?:ORIGIN=|FROM=|DEPARTURE=|\\b)([A-Z]{3})(?:[-_]|&(?:DEST|TO|ARRIVAL)=)([A-Z]{3})\\b"),
               let match = regex.firstMatch(in: upperUrl, range: NSRange(upperUrl.startIndex..., in: upperUrl)),
               let r1 = Range(match.range(at: 1), in: upperUrl),
               let r2 = Range(match.range(at: 2), in: upperUrl) {
                origen = String(upperUrl[r1])
                destino = String(upperUrl[r2])
            }
        }
        
        // 2. Al introducir un localizador (5-6 caracteres), completa automáticamente origen, destino y enlace de gestión
        if loc.count >= 5 {
            actualizarOrigenDestinoPorDefecto(paraTrayecto: trayecto)
            if urlReserva.isEmpty {
                let encodedLoc = loc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? loc
                if aerolinea.lowercased().contains("iberia") {
                    urlReserva = "https://www.iberia.com/es/gestion-reservas/?pnr=\(encodedLoc)"
                } else if aerolinea.lowercased().contains("ryanair") {
                    urlReserva = "https://www.ryanair.com/es/es/mybookings"
                } else if aerolinea.lowercased().contains("vueling") {
                    urlReserva = "https://www.vueling.com/es/servicios-vueling/gestiona-tu-reserva"
                } else {
                    urlReserva = "https://www.checkmytrip.com/cmt/apf/cmtng/index?pnr=\(encodedLoc)"
                }
            }
            if !origen.isEmpty && !destino.isEmpty {
                mensajeAutocompletado = "✓ Localizador \(loc): ruta \(origen) → \(destino) marcada"
            } else {
                mensajeAutocompletado = "✓ Localizador \(loc) vinculado para check-in"
            }
        }
    }
    
    private func autocompletarVuelo(codigoBruto: String) {
        let code = codigoBruto.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: " ", with: "")
        guard code.count >= 2 else {
            mensajeAutocompletado = ""
            return
        }
        
        // 1. Detección automática de aerolínea y web oficial por prefijo IATA (2 letras)
        let prefijo = String(code.prefix(2))
        let aerolineasPorPrefijo: [String: (nombre: String, url: String, terminalDefault: String)] = [
            "IB": ("Iberia", "https://www.iberia.com/es/gestion-reservas/", "Terminal 4"),
            "I2": ("Iberia Express", "https://www.iberiaexpress.com", "Terminal 4"),
            "VY": ("Vueling", "https://www.vueling.com/es/servicios-vueling/gestiona-tu-reserva", "Terminal 1"),
            "FR": ("Ryanair", "https://www.ryanair.com/es/es/mybookings", "Terminal Principal"),
            "UX": ("Air Europa", "https://www.aireuropa.com", "Terminal 2"),
            "U2": ("easyJet", "https://www.easyjet.com/es", "Terminal 1"),
            "LH": ("Lufthansa", "https://www.lufthansa.com", "Terminal 2"),
            "AF": ("Air France", "https://wwws.airfrance.es", "Terminal 2"),
            "BA": ("British Airways", "https://www.britishairways.com", "Terminal 4S"),
            "KL": ("KLM", "https://www.klm.es", "Terminal 2"),
            "TP": ("TAP Air Portugal", "https://www.flytap.com", "Terminal 2"),
            "AZ": ("ITA Airways", "https://www.ita-airways.com", "Terminal 2"),
            "W6": ("Wizz Air", "https://wizzair.com", "Terminal 1"),
            "DY": ("Norwegian", "https://www.norwegian.com", "Terminal 1")
        ]
        
        if let infoAerolinea = aerolineasPorPrefijo[prefijo] {
            aerolinea = infoAerolinea.nombre
            if urlReserva.isEmpty {
                urlReserva = infoAerolinea.url
            }
            if terminal.isEmpty {
                terminal = infoAerolinea.terminalDefault
            }
            mensajeAutocompletado = "✓ Aerolínea detectada: \(infoAerolinea.nombre)"
        }
        
        // 2. Base de datos de rutas y horarios conocidos (se rellena al instante al terminar el número)
        struct RutaVuelo {
            let trayecto: String
            let origen: String
            let destino: String
            let horaSalida: Int
            let minSalida: Int
            let duracionMin: Int
            let terminal: String
        }
        
        let rutasConocidas: [String: RutaVuelo] = [
            "IB3140": RutaVuelo(trayecto: "Ida", origen: "MAD", destino: "PRG", horaSalida: 8, minSalida: 30, duracionMin: 175, terminal: "Terminal 4"),
            "IB3141": RutaVuelo(trayecto: "Vuelta", origen: "PRG", destino: "MAD", horaSalida: 12, minSalida: 15, duracionMin: 180, terminal: "Terminal 2"),
            "FR2418": RutaVuelo(trayecto: "Vuelta", origen: "KRK", destino: "MAD", horaSalida: 17, minSalida: 10, duracionMin: 215, terminal: "Terminal Principal"),
            "FR2417": RutaVuelo(trayecto: "Ida", origen: "MAD", destino: "KRK", horaSalida: 12, minSalida: 50, duracionMin: 210, terminal: "Terminal 1"),
            "VY1002": RutaVuelo(trayecto: "Ida", origen: "BCN", destino: "FCO", horaSalida: 10, minSalida: 15, duracionMin: 110, terminal: "Terminal 1"),
            "VY1003": RutaVuelo(trayecto: "Vuelta", origen: "FCO", destino: "BCN", horaSalida: 13, minSalida: 0, duracionMin: 115, terminal: "Terminal 3"),
            "UX1093": RutaVuelo(trayecto: "Ida", origen: "MAD", destino: "ORY", horaSalida: 15, minSalida: 0, duracionMin: 125, terminal: "Terminal 2"),
            "UX1094": RutaVuelo(trayecto: "Vuelta", origen: "ORY", destino: "MAD", horaSalida: 18, minSalida: 10, duracionMin: 125, terminal: "Terminal 1"),
            "IB3250": RutaVuelo(trayecto: "Ida", origen: "MAD", destino: "FCO", horaSalida: 9, minSalida: 45, duracionMin: 150, terminal: "Terminal 4"),
            "IB3251": RutaVuelo(trayecto: "Vuelta", origen: "FCO", destino: "MAD", horaSalida: 13, minSalida: 20, duracionMin: 155, terminal: "Terminal 1"),
            "IB3402": RutaVuelo(trayecto: "Ida", origen: "MAD", destino: "ORY", horaSalida: 8, minSalida: 50, duracionMin: 125, terminal: "Terminal 4"),
            "IB3166": RutaVuelo(trayecto: "Ida", origen: "MAD", destino: "LHR", horaSalida: 10, minSalida: 15, duracionMin: 150, terminal: "Terminal 4S"),
            "TP1015": RutaVuelo(trayecto: "Ida", origen: "MAD", destino: "LIS", horaSalida: 11, minSalida: 30, duracionMin: 80, terminal: "Terminal 2")
        ]
        
        if let ruta = rutasConocidas[code] {
            trayecto = ruta.trayecto
            origen = ruta.origen
            destino = ruta.destino
            terminal = ruta.terminal
            
            let fechaBase = (ruta.trayecto == "Vuelta") ? escapada.fechaFin : escapada.fechaInicio
            if let salCalc = Calendar.current.date(bySettingHour: ruta.horaSalida, minute: ruta.minSalida, second: 0, of: fechaBase) {
                salida = salCalc
                llegada = Calendar.current.date(byAdding: .minute, value: ruta.duracionMin, to: salCalc) ?? salCalc
            }
            mensajeAutocompletado = "✨ Vuelo \(code) completado: \(ruta.origen) → \(ruta.destino)"
        } else if code.count >= 5, aerolineasPorPrefijo[prefijo] != nil {
            if origen.isEmpty {
                origen = "MAD"
            }
            mensajeAutocompletado = "✓ \(aerolinea) detectada. Completa origen/destino."
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
    @State private var codigoInput: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Estado de sincronización") {
                    HStack {
                        Text("Estado")
                        Spacer()
                        Text(store.estadoNube)
                            .foregroundStyle(store.estadoNube == "En vivo" ? .green : .orange)
                            .font(.subheadline.bold())
                    }
                    HStack {
                        Text("Código actual")
                        Spacer()
                        Text(store.codigoPareja)
                            .font(.headline.monospaced())
                    }
                }
                
                Section("Conectar ambos iPhones") {
                    TextField("Escribe vuestro código (ej: AMOR-2026)", text: $codigoInput)
                        .font(.headline.monospaced())
                        .autocapitalization(.allCharacters)
                    
                    Button("Conectar a este código") {
                        store.conectarASala(codigo: codigoInput)
                        dismiss()
                    }
                    .disabled(codigoInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    
                    Text("Introducid exactamente el mismo código en los dos iPhones. Todo lo que añada uno aparecerá al instante en el otro.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sincronización")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                codigoInput = store.codigoPareja
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}