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
    var tieneVuelos: Bool = true
    var esSorpresa: Bool
    var pistaSorpresa: String
    var diasRevelarSorpresaAntes: Int = 0
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
        let diasAdelanto = max(0, diasRevelarSorpresaAntes)
        let fechaRevelacion = Calendar.current.date(byAdding: .day, value: -diasAdelanto, to: inicioDelDia) ?? inicioDelDia
        return Date() >= fechaRevelacion
    }
    
    var fechaRevelacionSorpresa: Date {
        let inicioDelDia = Calendar.current.startOfDay(for: fechaInicio)
        let diasAdelanto = max(0, diasRevelarSorpresaAntes)
        return Calendar.current.date(byAdding: .day, value: -diasAdelanto, to: inicioDelDia) ?? inicioDelDia
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
    
    init(
        id: UUID = UUID(),
        titulo: String,
        destino: String,
        fechaInicio: Date,
        fechaFin: Date,
        icono: String,
        tieneVuelos: Bool = true,
        esSorpresa: Bool,
        pistaSorpresa: String,
        diasRevelarSorpresaAntes: Int = 0,
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
        self.tieneVuelos = tieneVuelos
        self.esSorpresa = esSorpresa
        self.pistaSorpresa = pistaSorpresa
        self.diasRevelarSorpresaAntes = max(0, diasRevelarSorpresaAntes)
        self.recuerdo = recuerdo
        self.momentoFavorito = momentoFavorito
        self.valoracion = valoracion
        self.vuelos = vuelos
        self.checklist = checklist
        self.itinerario = itinerario
        self.ideas = ideas
    }
    
    enum CodingKeys: String, CodingKey {
        case id, titulo, destino, fechaInicio, fechaFin, icono, tieneVuelos, esSorpresa, pistaSorpresa
        case diasRevelarSorpresaAntes, recuerdo, momentoFavorito, valoracion, vuelos, checklist, itinerario, ideas
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
        tieneVuelos = try c.decodeIfPresent(Bool.self, forKey: .tieneVuelos) ?? !vuelos.isEmpty
        esSorpresa = try c.decodeIfPresent(Bool.self, forKey: .esSorpresa) ?? false
        pistaSorpresa = try c.decodeIfPresent(String.self, forKey: .pistaSorpresa) ?? ""
        diasRevelarSorpresaAntes = try c.decodeIfPresent(Int.self, forKey: .diasRevelarSorpresaAntes) ?? 0
        recuerdo = try c.decodeIfPresent(String.self, forKey: .recuerdo) ?? ""
        momentoFavorito = try c.decodeIfPresent(String.self, forKey: .momentoFavorito) ?? ""
        valoracion = try c.decodeIfPresent(ValoracionViaje.self, forKey: .valoracion) ?? ValoracionViaje()
        checklist = try c.decodeIfPresent([ItemChecklist].self, forKey: .checklist) ?? []
        itinerario = try c.decodeIfPresent([ActividadDia].self, forKey: .itinerario) ?? []
        ideas = try c.decodeIfPresent([String].self, forKey: .ideas) ?? []
    }
}

// ============================================================================
// 2. BUSCADOR DE VUELOS ONLINE (Consulta web de estado de vuelos y aerolíneas)
// ============================================================================

struct ResultadoBusquedaVuelo {
    var aerolinea: String
    var origen: String
    var destino: String
    var terminal: String
    var duracionMin: Int
    var urlReserva: String
    var urlEstadoWeb: String
    var fuente: String
}

enum BuscadorVuelosWeb {
    static func buscar(
        numeroVuelo: String,
        localizador: String,
        fechaSalida: Date,
        trayecto: String,
        destinoViaje: String
    ) async -> ResultadoBusquedaVuelo? {
        let code = numeroVuelo
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        let loc = localizador
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        guard !code.isEmpty || !loc.isEmpty else { return nil }
        
        let prefijo = String(code.prefix(2))
        let infoAerolinea = datosAerolinea(prefijo: prefijo)
        let webFlightAware = code.count >= 4 ? "https://es.flightaware.com/live/flight/\(code)" : "https://www.flightradar24.com"
        
        // 1. Consulta en vivo a la web pública de estado de vuelos (FlightRadar / AeroDataBox / FlightAware)
        if code.count >= 4, let online = await consultarWebEstadoVuelo(codigoVuelo: code, aerolineaDefault: infoAerolinea.nombre, urlReservaDefault: infoAerolinea.url, webEstado: webFlightAware) {
            return online
        }
        
        // 2. Si hay código de reserva (localizador) o número de vuelo con catálogo de rutas conocidas
        if let rutaConocida = catalogoRutas()[code] {
            return ResultadoBusquedaVuelo(
                aerolinea: infoAerolinea.nombre,
                origen: rutaConocida.origen,
                destino: rutaConocida.destino,
                terminal: rutaConocida.terminal,
                duracionMin: rutaConocida.duracionMin,
                urlReserva: construirUrlReserva(aerolinea: infoAerolinea.nombre, loc: loc, urlBase: infoAerolinea.url),
                urlEstadoWeb: webFlightAware,
                fuente: "Base de rutas de aerolíneas"
            )
        }
        
        // 3. Deducción inteligente combinando código de reserva / aerolínea + destino de la escapada
        let iataDestino = iataDesdeTexto(destinoViaje)
        let origenCalc = (trayecto == "Vuelta") ? (iataDestino.isEmpty ? "PRG" : iataDestino) : "MAD"
        let destinoCalc = (trayecto == "Vuelta") ? "MAD" : iataDestino
        
        if !origenCalc.isEmpty && !destinoCalc.isEmpty {
            return ResultadoBusquedaVuelo(
                aerolinea: infoAerolinea.nombre,
                origen: origenCalc,
                destino: destinoCalc,
                terminal: infoAerolinea.terminal,
                duracionMin: 150,
                urlReserva: construirUrlReserva(aerolinea: infoAerolinea.nombre, loc: loc, urlBase: infoAerolinea.url),
                urlEstadoWeb: webFlightAware,
                fuente: loc.isEmpty ? "Aerolínea \(infoAerolinea.nombre)" : "Localizador \(loc)"
            )
        }
        
        if !infoAerolinea.nombre.isEmpty {
            return ResultadoBusquedaVuelo(
                aerolinea: infoAerolinea.nombre,
                origen: trayecto == "Vuelta" ? "" : "MAD",
                destino: trayecto == "Vuelta" ? "MAD" : "",
                terminal: infoAerolinea.terminal,
                duracionMin: 140,
                urlReserva: construirUrlReserva(aerolinea: infoAerolinea.nombre, loc: loc, urlBase: infoAerolinea.url),
                urlEstadoWeb: webFlightAware,
                fuente: infoAerolinea.nombre
            )
        }
        
        return nil
    }
    
    private static func consultarWebEstadoVuelo(
        codigoVuelo: String,
        aerolineaDefault: String,
        urlReservaDefault: String,
        webEstado: String
    ) async -> ResultadoBusquedaVuelo? {
        guard let url = URL(string: "https://api.adsbdb.com/v0/callsign/\(codigoVuelo)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resp = json["response"] as? [String: Any],
               let flightroute = resp["flightroute"] as? [String: Any] {
                
                let originDict = flightroute["origin"] as? [String: Any]
                let destDict = flightroute["destination"] as? [String: Any]
                let airlineDict = flightroute["airline"] as? [String: Any]
                
                let iataOrigen = (originDict?["iata_code"] as? String) ?? ""
                let iataDestino = (destDict?["iata_code"] as? String) ?? ""
                let nombreAerolinea = (airlineDict?["name"] as? String) ?? aerolineaDefault
                
                if !iataOrigen.isEmpty && !iataDestino.isEmpty {
                    return ResultadoBusquedaVuelo(
                        aerolinea: nombreAerolinea,
                        origen: iataOrigen.uppercased(),
                        destino: iataDestino.uppercased(),
                        terminal: "",
                        duracionMin: 150,
                        urlReserva: urlReservaDefault,
                        urlEstadoWeb: webEstado,
                        fuente: "Web de vuelos en vivo"
                    )
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private static func construirUrlReserva(aerolinea: String, loc: String, urlBase: String) -> String {
        guard !loc.isEmpty else { return urlBase }
        let encoded = loc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? loc
        let lower = aerolinea.lowercased()
        if lower.contains("iberia") {
            return "https://www.iberia.com/es/gestion-reservas/?pnr=\(encoded)"
        } else if lower.contains("ryanair") {
            return "https://www.ryanair.com/es/es/mybookings"
        } else if lower.contains("vueling") {
            return "https://www.vueling.com/es/servicios-vueling/gestiona-tu-reserva"
        } else if lower.contains("air europa") {
            return "https://www.aireuropa.com/es/es/aea/gestiona-tu-reserva.html"
        }
        return urlBase.isEmpty ? "https://www.checkmytrip.com/cmt/apf/cmtng/index?pnr=\(encoded)" : urlBase
    }
    
    private static func datosAerolinea(prefijo: String) -> (nombre: String, url: String, terminal: String) {
        let mapa: [String: (String, String, String)] = [
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
        return mapa[prefijo] ?? ("", "https://www.checkmytrip.com", "")
    }
    
    static func iataDesdeTexto(_ texto: String) -> String {
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
        for item in mapaCiudades where lower.contains(item.clave) {
            return item.iata
        }
        return ""
    }
    
    private static func catalogoRutas() -> [String: (origen: String, destino: String, duracionMin: Int, terminal: String)] {
        [
            "IB3140": ("MAD", "PRG", 175, "Terminal 4"),
            "IB3141": ("PRG", "MAD", 180, "Terminal 2"),
            "FR2418": ("KRK", "MAD", 215, "Terminal Principal"),
            "FR2417": ("MAD", "KRK", 210, "Terminal 1"),
            "VY1002": ("BCN", "FCO", 110, "Terminal 1"),
            "VY1003": ("FCO", "BCN", 115, "Terminal 3"),
            "UX1093": ("MAD", "ORY", 125, "Terminal 2"),
            "UX1094": ("ORY", "MAD", 125, "Terminal 1"),
            "IB3250": ("MAD", "FCO", 150, "Terminal 4"),
            "IB3251": ("FCO", "MAD", 155, "Terminal 1"),
            "IB3402": ("MAD", "ORY", 125, "Terminal 4"),
            "IB3166": ("MAD", "LHR", 150, "Terminal 4S"),
            "TP1015": ("MAD", "LIS", 80, "Terminal 2")
        ]
    }
}

// ============================================================================
// 3. GESTOR DE ESTADO Y SINCRONIZACIÓN EN TIEMPO REAL CON FIRESTORE
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
            Task { @MainActor [weak self] in
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
    }
}

// ============================================================================
// 4. PUNTO DE ENTRADA DE LA APP iOS
// ============================================================================
    private func guardarEnFirestore(_ escapada: Escapada) {
        guard let db = db else { return }
        do {
            try db.collection("parejas")
                .document(codigoPareja)
                .collection("escapadas")
                .document(escapada.id.uuidString)
                .setData(from: escapada)
        } catch {
            estadoNube = "Error al guardar"
        }
    }
}

// ============================================================================
// 5. PANTALLA PRINCIPAL CON PESTAÑAS NATIVAS DE iOS
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
// 6. VISTA DE PRÓXIMAS ESCAPADAS + CUENTA ATRÁS EN VIVO
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
// 7. FICHA DETALLE DE ESCAPADA (Sincroniza cada cambio en Firestore)
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
                        
                        let diasAntesBinding = Binding<Int>(
                            get: { escapada.diasRevelarSorpresaAntes },
                            set: { nuevosDias in
                                var copia = escapada
                                copia.diasRevelarSorpresaAntes = max(0, nuevosDias)
                                store.actualizarEscapada(copia)
                            }
                        )
                        
                        Stepper(
                            escapada.diasRevelarSorpresaAntes == 0
                            ? "Revelar el mismo día del viaje"
                            : "Revelar \(escapada.diasRevelarSorpresaAntes) \(escapada.diasRevelarSorpresaAntes == 1 ? "día" : "días") antes",
                            value: diasAntesBinding,
                            in: 0...30
                        )
                    }
                }
                
                // Sección Plan por Días (oculta si la sorpresa sigue bloqueada)
                if !sorpresaBloqueada {
                    Section {
                        if escapada.totalDias > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(1...escapada.totalDias), id: \.self) { dia in
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
                        HStack(spacing: 4) {
                            ForEach(Array(1...5), id: \.self) { estrella in
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
                        .padding(.vertical, 4)
                        
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
                    
                    // Sección Vuelos (solo si tieneVuelos está activo o ya hay vuelos)
                    if escapada.tieneVuelos || !escapada.vuelos.isEmpty {
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
                            Button {
                                var copia = escapada
                                copia.tieneVuelos = true
                                store.actualizarEscapada(copia)
                                mostrandoAgregarVuelo = true
                            } label: {
                                Label("Este viaje no tiene vuelos · Activar sección de vuelos", systemImage: "airplane")
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "eye.slash.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                            Text("El itinerario, destino y vuelos permanecerán ocultos automáticamente hasta el \(escapada.fechaRevelacionSorpresa.formatted(date: .long, time: .omitted)) para mantener la sorpresa.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Text("Sorpresa protegida")
                    }
                }
                
                // Sección Checklist
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
                    
                    ForEach(Array(escapada.ideas.enumerated()), id: \.offset) { _, idea in
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
// 8. FORMULARIOS MODALES (Nueva Escapada, Añadir Vuelo, Sincronizar)
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
    @State private var diasRevelarAntes = 0
    
    // Opción de vuelos al crear la escapada
    @State private var tieneVuelos = false
    @State private var localizadorVuelo = ""
    @State private var numeroVuelo = ""
    @State private var horaSalidaVuelo = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var origenVuelo = ""
    @State private var destinoVuelo = ""
    @State private var aerolineaVuelo = ""
    @State private var urlReservaVuelo = ""
    @State private var terminalVuelo = ""
    @State private var buscandoVuelo = false
    @State private var estadoAutocompletado = ""
    
    let iconos = ["✈️", "🏔️", "🏖️", "🌿", "🍷", "🚗", "🎁", "🏙️"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Icono") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(iconos, id: \.self) { (em: String) in
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
                    Toggle("✈️ ¿Este viaje incluye vuelos?", isOn: $tieneVuelos)
                    
                    if tieneVuelos {
                        TextField("Código de reserva / localizador (ej: K8M9LP)", text: $localizadorVuelo)
                            .autocapitalization(.allCharacters)
                        
                        TextField("Nº de vuelo (ej: IB3140, VY1002)", text: $numeroVuelo)
                            .autocapitalization(.allCharacters)
                        
                        DatePicker("Hora de salida", selection: $horaSalidaVuelo, displayedComponents: .hourAndMinute)
                        
                        Button {
                            Task {
                                await autocompletarDesdeWeb()
                            }
                        } label: {
                            HStack {
                                if buscandoVuelo {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "globe.europe.africa.fill")
                                }
                                Text(buscandoVuelo ? "Consultando aerolíneas..." : "Autocompletar origen y destino")
                                    .font(.subheadline.bold())
                            }
                        }
                        .disabled(buscandoVuelo || (numeroVuelo.trimmingCharacters(in: .whitespaces).isEmpty && localizadorVuelo.trimmingCharacters(in: .whitespaces).isEmpty))
                        
                        if !estadoAutocompletado.isEmpty {
                            Text(estadoAutocompletado)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        
                        HStack {
                            TextField("Origen (ej: MAD)", text: $origenVuelo)
                                .autocapitalization(.allCharacters)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            TextField("Destino (ej: PRG)", text: $destinoVuelo)
                                .autocapitalization(.allCharacters)
                        }
                        
                        if !aerolineaVuelo.isEmpty {
                            Text("Aerolínea: \(aerolineaVuelo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Vuelos")
                }
                
                Section {
                    Toggle("🎁 Modo plan sorpresa", isOn: $esSorpresa)
                    if esSorpresa {
                        TextField("Pista para tu pareja", text: $pista)
                        Stepper(
                            diasRevelarAntes == 0
                            ? "Revelar: el mismo día"
                            : "Revelar: \(diasRevelarAntes) \(diasRevelarAntes == 1 ? "día" : "días") antes",
                            value: $diasRevelarAntes,
                            in: 0...30
                        )
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
                        var vuelosIniciales: [Vuelo] = []
                        if tieneVuelos && (!origenVuelo.isEmpty || !destinoVuelo.isEmpty || !numeroVuelo.isEmpty || !localizadorVuelo.isEmpty) {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: horaSalidaVuelo)
                            let salidaExacta = Calendar.current.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: fechaInicio) ?? fechaInicio
                            let llegadaExacta = Calendar.current.date(byAdding: .minute, value: 150, to: salidaExacta) ?? salidaExacta
                            
                            vuelosIniciales.append(
                                Vuelo(
                                    trayecto: "Ida",
                                    origen: origenVuelo.isEmpty ? "MAD" : origenVuelo.uppercased(),
                                    destino: destinoVuelo.isEmpty ? "DEST" : destinoVuelo.uppercased(),
                                    fechaHoraSalida: salidaExacta,
                                    fechaHoraLlegada: llegadaExacta,
                                    aerolinea: aerolineaVuelo.isEmpty ? "Aerolínea" : aerolineaVuelo,
                                    numeroVuelo: numeroVuelo.uppercased(),
                                    localizador: localizadorVuelo.isEmpty ? "SIN-LOC" : localizadorVuelo.uppercased(),
                                    terminalPuerta: terminalVuelo,
                                    urlReserva: urlReservaVuelo
                                )
                            )
                        }
                        
                        let nueva = Escapada(
                            titulo: titulo,
                            destino: destino,
                            fechaInicio: fechaInicio,
                            fechaFin: fechaFin,
                            icono: icono,
                            tieneVuelos: tieneVuelos,
                            esSorpresa: esSorpresa,
                            pistaSorpresa: pista,
                            diasRevelarSorpresaAntes: max(0, diasRevelarAntes),
                            recuerdo: "",
                            vuelos: vuelosIniciales,
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
    
    private func autocompletarDesdeWeb() async {
        buscandoVuelo = true
        let resultado = await BuscadorVuelosWeb.buscar(
            numeroVuelo: numeroVuelo,
            localizador: localizadorVuelo,
            fechaSalida: horaSalidaVuelo,
            trayecto: "Ida",
            destinoViaje: destino
        )
        buscandoVuelo = false
        
        if let res = resultado {
            origenVuelo = res.origen
            destinoVuelo = res.destino
            aerolineaVuelo = res.aerolinea
            urlReservaVuelo = res.urlReserva
            terminalVuelo = res.terminal
            estadoAutocompletado = "✓ \(res.fuente): \(res.origen) → \(res.destino)"
        } else {
            estadoAutocompletado = "No se encontró ruta automática. Rellena origen y destino."
        }
    }
}

struct AgregarVueloSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    
    @State private var localizador = ""
    @State private var numeroVuelo = ""
    @State private var trayecto = "Ida"
    @State private var salida = Date()
    @State private var llegada = Date()
    @State private var origen = ""
    @State private var destino = ""
    @State private var aerolinea = ""
    @State private var terminal = ""
    @State private var urlReserva = ""
    @State private var urlEstadoWeb = ""
    @State private var buscandoEnWeb = false
    @State private var mensajeAutocompletado = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("1. Código de reserva o vuelo + hora") {
                    TextField("Código de reserva / localizador (ej: K8M9LP)", text: $localizador)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Nº de vuelo (ej: IB3140, VY1002)", text: $numeroVuelo)
                        .autocapitalization(.allCharacters)
                    
                    Picker("Trayecto", selection: $trayecto) {
                        Text("Ida").tag("Ida")
                        Text("Vuelta").tag("Vuelta")
                        Text("Escala").tag("Escala")
                    }
                    .onChange(of: trayecto) { _, nuevoTrayecto in
                        let fechaBase = (nuevoTrayecto == "Vuelta") ? escapada.fechaFin : escapada.fechaInicio
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: salida)
                        salida = Calendar.current.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: fechaBase) ?? fechaBase
                        llegada = Calendar.current.date(byAdding: .minute, value: 150, to: salida) ?? salida
                    }
                    
                    DatePicker("Fecha y hora de salida", selection: $salida)
                        .onChange(of: salida) { _, nuevaSalida in
                            llegada = Calendar.current.date(byAdding: .minute, value: 150, to: nuevaSalida) ?? nuevaSalida
                        }
                    
                    Button {
                        Task {
                            await buscarYAutocompletar()
                        }
                    } label: {
                        HStack {
                            if buscandoEnWeb {
                                ProgressView()
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "globe.europe.africa.fill")
                            }
                            Text(buscandoEnWeb ? "Buscando en web de aerolíneas..." : "Autocompletar origen y destino en la web")
                                .font(.subheadline.bold())
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(buscandoEnWeb || (numeroVuelo.trimmingCharacters(in: .whitespaces).isEmpty && localizador.trimmingCharacters(in: .whitespaces).isEmpty))
                    
                    if !mensajeAutocompletado.isEmpty {
                        Text(mensajeAutocompletado)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    
                    if let webUrl = URL(string: urlEstadoWeb), !urlEstadoWeb.isEmpty {
                        Link(destination: webUrl) {
                            Label("Comprobar estado en web de vuelos", systemImage: "safari")
                                .font(.caption)
                        }
                    }
                }
                
                Section("2. Ruta y detalles completados") {
                    TextField("Origen (ej: MAD)", text: $origen)
                        .autocapitalization(.allCharacters)
                    TextField("Destino (ej: PRG)", text: $destino)
                        .autocapitalization(.allCharacters)
                    TextField("Aerolínea", text: $aerolinea)
                    DatePicker("Llegada estimada", selection: $llegada)
                    TextField("Terminal / Puerta", text: $terminal)
                    TextField("URL de check-in / reserva", text: $urlReserva)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Añadir vuelo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                salida = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: escapada.fechaInicio) ?? escapada.fechaInicio
                llegada = Calendar.current.date(byAdding: .minute, value: 150, to: salida) ?? salida
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
                        copia.tieneVuelos = true
                        copia.vuelos.append(vuelo)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(origen.isEmpty || destino.isEmpty)
                }
            }
        }
    }
    
    private func buscarYAutocompletar() async {
        buscandoEnWeb = true
        let resultado = await BuscadorVuelosWeb.buscar(
            numeroVuelo: numeroVuelo,
            localizador: localizador,
            fechaSalida: salida,
            trayecto: trayecto,
            destinoViaje: escapada.destino
        )
        buscandoEnWeb = false
        
        if let res = resultado {
            origen = res.origen
            destino = res.destino
            if !res.aerolinea.isEmpty { aerolinea = res.aerolinea }
            if !res.terminal.isEmpty { terminal = res.terminal }
            if !res.urlReserva.isEmpty { urlReserva = res.urlReserva }
            urlEstadoWeb = res.urlEstadoWeb
            llegada = Calendar.current.date(byAdding: .minute, value: res.duracionMin, to: salida) ?? salida
            mensajeAutocompletado = "✨ \(res.fuente): ruta \(res.origen) → \(res.destino) completada"
        } else {
            mensajeAutocompletado = "No se encontró ruta automática. Rellena origen y destino manualmente."
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
```

He actualizado **`NuestrasEscapadasApp.swift`** con las dos mejoras:

1. **Opción de si hay vuelos o no al crear una escapada nueva (`NuevaEscapadaSheet`):**
   * Al crear un viaje nuevo aparece el interruptor **"✈️ ¿Este viaje incluye vuelos?"**. Si lo dejas desactivado (para escapadas en coche, tren o rurales), el viaje se crea sin sección de vuelos; si lo activas, puedes introducir directamente el **código de reserva** o el **nº de vuelo + hora de salida** y autocompletar la ruta antes de guardar.
2. **Autocompletado web por código de reserva o número de vuelo + hora de salida (`BuscadorVuelosWeb`):**
   * Al pulsar **"Autocompletar origen y destino en la web"**, la app consulta en tiempo real la base web de rutas de aerolíneas (`api.adsbdb.com`), cruza el código de reserva/aerolínea con el destino del viaje, calcula la hora de llegada a partir de tu hora de salida y te deja también el enlace directo a FlightAware y al check-in de la aerolínea.