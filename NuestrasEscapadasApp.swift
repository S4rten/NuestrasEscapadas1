import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseFirestore

// ============================================================================
// MARK: - 1. PUNTO DE ENTRADA E INICIALIZACIÓN DE FIREBASE
// ============================================================================

@main
struct NuestrasEscapadasApp: App {
    @StateObject private var store = EscapadasStore()

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Color.terracota)
        }
    }
}

// ============================================================================
// MARK: - 2. PALETA DE COLORES Y ESTILOS VISUALES
// ============================================================================

extension Color {
    static let crema = Color(red: 0.98, green: 0.97, blue: 0.96)
    static let terracota = Color(red: 0.88, green: 0.43, blue: 0.33)
    static let terracotaSuave = Color(red: 0.99, green: 0.95, blue: 0.93)
    static let tinta = Color(red: 0.12, green: 0.16, blue: 0.23)
    static let arena = Color(red: 0.94, green: 0.93, blue: 0.90)
}

// ============================================================================
// MARK: - 3. MODELOS DE DATOS
// ============================================================================

struct Vuelo: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var trayecto: String
    var origen: String
    var destino: String
    var fechaHoraSalida: Date
    var fechaHoraLlegada: Date
    var aerolinea: String
    var numeroVuelo: String
    var localizador: String
    var terminalPuerta: String
    var urlReserva: String
}

struct TrenViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var trayecto: String
    var operadora: String
    var estacionOrigen: String
    var estacionDestino: String
    var fechaHoraSalida: Date
    var fechaHoraLlegada: Date
    var localizador: String
    var cocheAsiento: String = ""
    var urlReserva: String = ""
}

struct AlojamientoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var nombre: String
    var direccion: String
    var fechaEntrada: Date
    var fechaSalida: Date
    var localizador: String
    var notas: String
}

struct ItemChecklist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var texto: String
    var completado: Bool
    var asignadoA: String
}

struct GastoViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var concepto: String
    var importeOriginal: Double
    var codigoDivisa: String
    var importeEuros: Double
    var pagadoPor: String
    var fecha: Date = Date()
}

struct ActividadDia: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var diaNumero: Int
    var hora: String
    var titulo: String
    var notas: String
}

struct ValoracionViaje: Codable, Hashable {
    var museos: Int = 0
    var comida: Int = 0
    var ciudad: Int = 0
    var alojamiento: Int = 0
    var momentosJuntos: Int = 0
}

struct Escapada: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var titulo: String
    var destino: String
    var fechaInicio: Date
    var fechaFin: Date
    var icono: String
    var tieneVuelos: Bool = false
    var tieneTrenes: Bool = false
    var esSorpresa: Bool = false
    var pistaSorpresa: String = ""
    var diasRevelarSorpresaAntes: Int = 0
    var recuerdo: String = ""
    var notasRapidas: String = ""
    var vuelos: [Vuelo] = []
    var trenes: [TrenViaje] = []
    var alojamientos: [AlojamientoItem] = []
    var checklist: [ItemChecklist] = []
    var gastos: [GastoViaje] = []
    var itinerario: [ActividadDia] = []
    var ideas: [String] = []
    var valoracion: ValoracionViaje = ValoracionViaje()

    var estaFinalizada: Bool {
        let finDia = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: fechaFin)) ?? fechaFin
        return Date() >= finDia
    }

    var totalGastadoEuros: Double {
        gastos.reduce(0) { $0 + $1.importeEuros }
    }
}

struct DivisaInfo: Identifiable, Hashable {
    let id: String
    let nombre: String
    let simbolo: String
    let tasaAEuros: Double
}

let DIVISAS_DISPONIBLES: [DivisaInfo] = [
    DivisaInfo(id: "EUR", nombre: "Euro", simbolo: "€", tasaAEuros: 1.0),
    DivisaInfo(id: "CZK", nombre: "Corona checa", simbolo: "Kč", tasaAEuros: 0.0398),
    DivisaInfo(id: "GBP", nombre: "Libra esterlina", simbolo: "£", tasaAEuros: 1.19),
    DivisaInfo(id: "USD", nombre: "Dólar EEUU", simbolo: "$", tasaAEuros: 0.92),
    DivisaInfo(id: "HUF", nombre: "Forinto húngaro", simbolo: "Ft", tasaAEuros: 0.00245),
    DivisaInfo(id: "PLN", nombre: "Złoty polaco", simbolo: "zł", tasaAEuros: 0.233),
    DivisaInfo(id: "CHF", nombre: "Franco suizo", simbolo: "CHF", tasaAEuros: 1.06),
    DivisaInfo(id: "JPY", nombre: "Yen japonés", simbolo: "¥", tasaAEuros: 0.0061)
]

// ============================================================================
// MARK: - 4. STORE Y SINCRONIZACIÓN EN TIEMPO REAL CON FIRESTORE
// ============================================================================

@MainActor
class EscapadasStore: ObservableObject {
    @Published var escapadas: [Escapada] = []
    @Published var codigoPareja: String = ""
    @Published var conectadoEnVivo: Bool = false
    @Published var mensajeEstado: String = "Iniciando..."

    private let claveLocalEscapadas = "nuestras_escapadas_cache_v3"
    private let claveLocalCodigo = "nuestras_escapadas_codigo_pareja_v3"
    private let claveDeviceId = "nuestras_escapadas_device_id_v1"

    private var listenerRegistration: ListenerRegistration?
    private var esPrimeraCargaSala = true
    private var ignorarProximoEcoLocal = false
    private let deviceId: String

    init() {
        if let savedDevice = UserDefaults.standard.string(forKey: claveDeviceId), !savedDevice.isEmpty {
            self.deviceId = savedDevice
        } else {
            let nuevoId = UUID().uuidString
            UserDefaults.standard.set(nuevoId, forKey: claveDeviceId)
            self.deviceId = nuevoId
        }

        cargarCacheLocal()

        if let savedCode = UserDefaults.standard.string(forKey: claveLocalCodigo), !savedCode.isEmpty {
            self.codigoPareja = Self.normalizarCodigo(savedCode)
        } else {
            let generado = Self.generarCodigoAleatorio()
            self.codigoPareja = generado
            UserDefaults.standard.set(generado, forKey: claveLocalCodigo)
        }

        conectarSala(codigo: self.codigoPareja)
    }

    static func normalizarCodigo(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let filtered = raw.uppercased().unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered)).prefix(20).description
    }

    static func generarCodigoAleatorio() -> String {
        let palabras = ["VIAJE", "RUTA", "SOL", "MAPA", "NUBE", "AMOR", "MAR"]
        let p = palabras.randomElement() ?? "VIAJE"
        let n = Int.random(in: 1000...9999)
        return "\(p)-\(n)"
    }

    func cambiarCodigoPareja(_ nuevo: String) {
        let limpio = Self.normalizarCodigo(nuevo)
        guard !limpio.isEmpty else { return }
        self.codigoPareja = limpio
        UserDefaults.standard.set(limpio, forKey: claveLocalCodigo)
        conectarSala(codigo: limpio)
    }

    func crearNuevoCodigoPareja() {
        cambiarCodigoPareja(Self.generarCodigoAleatorio())
    }

    func conectarSala(codigo: String) {
        listenerRegistration?.remove()
        listenerRegistration = nil
        esPrimeraCargaSala = true

        guard FirebaseApp.app() != nil else {
            conectadoEnVivo = false
            mensajeEstado = "Modo local (sin plist)"
            if escapadas.isEmpty {
                escapadas = Self.ejemplosIniciales()
                guardarCacheLocal()
            }
            return
        }

        conectadoEnVivo = false
        mensajeEstado = "Conectando..."
        let db = Firestore.firestore()
        let colRef = db.collection("parejas").document(codigo).collection("escapadas")

        listenerRegistration = colRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.conectadoEnVivo = false
                self.mensajeEstado = "Sin red"
                print("Error Firestore: \(error.localizedDescription)")
                return
            }

            guard let docs = snapshot?.documents else { return }
            self.conectadoEnVivo = true
            self.mensajeEstado = "En vivo"

            if self.esPrimeraCargaSala && docs.isEmpty {
                self.esPrimeraCargaSala = false
                let ejemplos = Self.ejemplosIniciales()
                self.escapadas = ejemplos
                self.guardarCacheLocal()
                for e in ejemplos {
                    self.subirEscapadaAFirestore(e)
                }
                return
            }

            let eraPrimera = self.esPrimeraCargaSala
            self.esPrimeraCargaSala = false

            var remotas: [Escapada] = []
            for doc in docs {
                if let jsonStr = doc.data()["payload"] as? String,
                   let data = jsonStr.data(using: .utf8),
                   let escapadaDecodificada = try? JSONDecoder().decode(Escapada.self, from: data) {
                    remotas.append(escapadaDecodificada)

                    let autorCambio = doc.data()["updatedByDevice"] as? String ?? ""
                    if !eraPrimera && !self.ignorarProximoEcoLocal && autorCambio != self.deviceId {
                        self.comprobarNotificacionNotasEIdeas(nueva: escapadaDecodificada)
                    }
                }
            }

            self.escapadas = remotas
            self.guardarCacheLocal()
        }
    }

    private func comprobarNotificacionNotasEIdeas(nueva: Escapada) {
        guard let anterior = escapadas.first(where: { $0.id == nueva.id }) else { return }
        let cambioNotas = anterior.notasRapidas.trimmingCharacters(in: .whitespacesAndNewlines) != nueva.notasRapidas.trimmingCharacters(in: .whitespacesAndNewlines)
        let cambioIdeas = anterior.ideas != nueva.ideas

        if cambioNotas || cambioIdeas {
            let content = UNMutableNotificationContent()
            content.title = "💕 Nuevo cambio en \(nueva.titulo)"
            if cambioNotas && cambioIdeas {
                content.body = "Tu pareja ha actualizado las notas rápidas e ideas del viaje."
            } else if cambioNotas {
                content.body = "Tu pareja ha editado las notas rápidas: \"\(nueva.notasRapidas)\""
            } else {
                content.body = "Tu pareja ha añadido o modificado una idea para \(nueva.destino)."
            }
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req)
        }
    }

    func agregarEscapada(_ escapada: Escapada) {
        escapadas.append(escapada)
        guardarCacheLocal()
        subirEscapadaAFirestore(escapada)
    }

    func actualizarEscapada(_ escapada: Escapada) {
        if let idx = escapadas.firstIndex(where: { $0.id == escapada.id }) {
            escapadas[idx] = escapada
            guardarCacheLocal()
            subirEscapadaAFirestore(escapada)
        }
    }

    func eliminarEscapada(_ id: UUID) {
        escapadas.removeAll { $0.id == id }
        guardarCacheLocal()

        guard FirebaseApp.app() != nil, !codigoPareja.isEmpty else { return }
        ignorarProximoEcoLocal = true
        Firestore.firestore()
            .collection("parejas")
            .document(codigoPareja)
            .collection("escapadas")
            .document(id.uuidString)
            .delete()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.ignorarProximoEcoLocal = false
        }
    }

    private func subirEscapadaAFirestore(_ escapada: Escapada) {
        guard FirebaseApp.app() != nil, !codigoPareja.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(escapada),
              let jsonStr = String(data: data, encoding: .utf8) else { return }

        ignorarProximoEcoLocal = true
        Firestore.firestore()
            .collection("parejas")
            .document(codigoPareja)
            .collection("escapadas")
            .document(escapada.id.uuidString)
            .setData([
                "payload": jsonStr,
                "updatedAt": FieldValue.serverTimestamp(),
                "updatedByDevice": deviceId
            ], merge: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.ignorarProximoEcoLocal = false
        }
    }

    private func guardarCacheLocal() {
        if let data = try? JSONEncoder().encode(escapadas) {
            UserDefaults.standard.set(data, forKey: claveLocalEscapadas)
        }
    }

    private func cargarCacheLocal() {
        if let data = UserDefaults.standard.data(forKey: claveLocalEscapadas),
           let guardadas = try? JSONDecoder().decode([Escapada].self, from: data) {
            self.escapadas = guardadas
        }
    }

    static func ejemplosIniciales() -> [Escapada] {
        let hoy = Date()
        let inicio1 = Calendar.current.date(byAdding: .day, value: 18, to: hoy) ?? hoy
        let fin1 = Calendar.current.date(byAdding: .day, value: 22, to: hoy) ?? hoy
        let inicioPasado = Calendar.current.date(byAdding: .day, value: -30, to: hoy) ?? hoy
        let finPasado = Calendar.current.date(byAdding: .day, value: -27, to: hoy) ?? hoy

        return [
            Escapada(
                titulo: "Escapada a Praga",
                destino: "Praga",
                fechaInicio: inicio1,
                fechaFin: fin1,
                icono: "✈️",
                tieneVuelos: true,
                tieneTrenes: false,
                notasRapidas: "Llevar calzado cómodo para empedrado y cambiar algo de efectivo al llegar.",
                vuelos: [
                    Vuelo(
                        trayecto: "Ida",
                        origen: "MAD",
                        destino: "PRG",
                        fechaHoraSalida: inicio1,
                        fechaHoraLlegada: inicio1.addingTimeInterval(10200),
                        aerolinea: "Iberia",
                        numeroVuelo: "IB3140",
                        localizador: "K8M9LP",
                        terminalPuerta: "T4",
                        urlReserva: "https://www.iberia.com"
                    )
                ],
                alojamientos: [
                    AlojamientoItem(
                        nombre: "Hotel Old Town Square",
                        direccion: "Staroměstské nám. 15, Praga",
                        fechaEntrada: inicio1,
                        fechaSalida: fin1,
                        localizador: "PRG-8821",
                        notas: "Check-in a partir de las 15:00"
                    )
                ],
                checklist: [
                    ItemChecklist(texto: "DNI / Pasaportes", completado: true, asignadoA: "Ambos"),
                    ItemChecklist(texto: "Abrigos térmicos", completado: false, asignadoA: "Ambos")
                ],
                gastos: [
                    GastoViaje(concepto: "Cena tradicional", importeOriginal: 1250, codigoDivisa: "CZK", importeEuros: 49.75, pagadoPor: "Yo")
                ],
                ideas: ["Puente de Carlos al amanecer", "Probar trdelník caliente"]
            ),
            Escapada(
                titulo: "Fin de semana en Sevilla",
                destino: "Sevilla",
                fechaInicio: inicioPasado,
                fechaFin: finPasado,
                icono: "🚂",
                tieneVuelos: false,
                tieneTrenes: true,
                recuerdo: "Tapeo increíble por Triana y atardecer inolvidable en Plaza de España.",
                trenes: [
                    TrenViaje(
                        trayecto: "Ida",
                        operadora: "Iryo",
                        estacionOrigen: "Madrid Atocha",
                        estacionDestino: "Sevilla Santa Justa",
                        fechaHoraSalida: inicioPasado,
                        fechaHoraLlegada: inicioPasado.addingTimeInterval(9300),
                        localizador: "IRY92X"
                    )
                ],
                gastos: [
                    GastoViaje(concepto: "Billetes de tren", importeOriginal: 118.0, codigoDivisa: "EUR", importeEuros: 118.0, pagadoPor: "Ambos"),
                    GastoViaje(concepto: "Tapas en Triana", importeOriginal: 64.5, codigoDivisa: "EUR", importeEuros: 64.5, pagadoPor: "Tú")
                ],
                valoracion: ValoracionViaje(museos: 5, comida: 5, ciudad: 5, alojamiento: 4, momentosJuntos: 5)
            )
        ]
    }
}

// ============================================================================
// MARK: - 5. VISTA PRINCIPAL CON PESTAÑAS (PRÓXIMAS / YA VIVIDO)
// ============================================================================

struct ContentView: View {
    @EnvironmentObject var store: EscapadasStore
    @State private var pestanaSeleccionada = 0
    @State private var mostrandoNuevaEscapada = false
    @State private var mostrandoSincronizacion = false

    var proximasEscapadas: [Escapada] {
        store.escapadas
            .filter { !$0.estaFinalizada }
            .sorted { $0.fechaInicio < $1.fechaInicio }
    }

    var escapadasVividas: [Escapada] {
        store.escapadas
            .filter { $0.estaFinalizada }
            .sorted { $0.fechaInicio > $1.fechaInicio }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.crema.ignoresSafeArea()

                TabView(selection: $pestanaSeleccionada) {
                    ProximasView(escapadas: proximasEscapadas)
                        .tabItem {
                            Label("Próximas", systemImage: "calendar")
                        }
                        .tag(0)

                    YaVividoView(escapadas: escapadasVividas)
                        .tabItem {
                            Label("Ya vivido", systemImage: "heart.fill")
                        }
                        .tag(1)
                }

                Button {
                    mostrandoNuevaEscapada = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.terracota)
                        .clipShape(Circle())
                        .shadow(color: Color.terracota.opacity(0.35), radius: 10, x: 0, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 64)
            }
            .navigationTitle("Nuestras Escapadas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mostrandoSincronizacion = true
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.conectadoEnVivo ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(store.codigoPareja)
                                .font(.caption.bold())
                                .foregroundColor(.tinta)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.arena, lineWidth: 1))
                    }
                }
            }
            .sheet(isPresented: $mostrandoNuevaEscapada) {
                NuevaEscapadaSheet()
            }
            .sheet(isPresented: $mostrandoSincronizacion) {
                SincronizacionParejaSheet()
            }
        }
    }
}

// ============================================================================
// MARK: - 6. PESTAÑA "PRÓXIMAS"
// ============================================================================

struct ProximasView: View {
    let escapadas: [Escapada]
    @State private var sorpresasReveladas: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if escapadas.isEmpty {
                    VStack(spacing: 12) {
                        Text("🗺️")
                            .font(.system(size: 48))
                        Text("Aún no hay escapadas próximas")
                            .font(.headline)
                            .foregroundColor(.tinta)
                        Text("Pulsa el botón + para planear vuestro siguiente viaje juntos.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(24)
                } else {
                    ForEach(Array(escapadas.enumerated()), id: \.element.id) { index, escapada in
                        NavigationLink(destination: DetalleEscapadaView(escapadaId: escapada.id)) {
                            TarjetaProximaEscapada(
                                escapada: escapada,
                                esPrincipal: index == 0,
                                revelada: sorpresasReveladas.contains(escapada.id),
                                onToggleRevelar: {
                                    if sorpresasReveladas.contains(escapada.id) {
                                        sorpresasReveladas.remove(escapada.id)
                                    } else {
                                        sorpresasReveladas.insert(escapada.id)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .background(Color.crema)
    }
}

struct TarjetaProximaEscapada: View {
    let escapada: Escapada
    let esPrincipal: Bool
    let revelada: Bool
    let onToggleRevelar: () -> Void

    var ocultaPorSorpresa: Bool {
        guard escapada.esSorpresa && !revelada else { return false }
        let diasRestantes = Calendar.current.dateComponents([.day], from: Date(), to: escapada.fechaInicio).day ?? 0
        return diasRestantes > escapada.diasRevelarSorpresaAntes
    }

    var diasCuentaAtras: Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: escapada.fechaInicio)).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(escapada.icono)
                    .font(.system(size: 32))
                    .frame(width: 54, height: 54)
                    .background(Color.terracotaSuave)
                    .cornerRadius(16)

                VStack(alignment: .leading, spacing: 4) {
                    if esPrincipal {
                        Text("PRÓXIMA PARADA")
                            .font(.caption2.bold())
                            .foregroundColor(.terracota)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.terracotaSuave)
                            .clipShape(Capsule())
                    }
                    Text(escapada.titulo)
                        .font(.title3.bold())
                        .foregroundColor(.tinta)
                    Text(ocultaPorSorpresa ? "🎁 Destino sorpresa oculto" : "📍 \(escapada.destino)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack {
                    Text("\(diasCuentaAtras)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(diasCuentaAtras == 1 ? "día" : "días")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 56, height: 56)
                .background(Color.terracota)
                .cornerRadius(16)
            }

            if ocultaPorSorpresa {
                HStack {
                    Text(escapada.pistaSorpresa.isEmpty ? "Pista secreta: ¡prepara la maleta!" : "Pista: \(escapada.pistaSorpresa)")
                        .font(.caption)
                        .foregroundColor(.terracota)
                    Spacer()
                    Button("Espiar") {
                        onToggleRevelar()
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.terracotaSuave)
                    .foregroundColor(.terracota)
                    .cornerRadius(10)
                }
            } else {
                HStack(spacing: 12) {
                    Label(formatearRangoFechas(escapada.fechaInicio, escapada.fechaFin), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !escapada.vuelos.isEmpty {
                        Label("\(escapada.vuelos.count) vuelo(s)", systemImage: "airplane")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !escapada.trenes.isEmpty {
                        Label("\(escapada.trenes.count) tren(es)", systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.arena, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// ============================================================================
// MARK: - 7. PESTAÑA "YA VIVIDO" (CON TOTAL GASTADO Y PUNTUACIONES)
// ============================================================================

struct YaVividoView: View {
    let escapadas: [Escapada]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recuerdos guardados")
                    .font(.title3.bold())
                    .foregroundColor(.tinta)
                    .padding(.horizontal, 4)

                if escapadas.isEmpty {
                    VStack(spacing: 12) {
                        Text("📸")
                            .font(.system(size: 44))
                        Text("Vuestro álbum empieza aquí")
                            .font(.headline)
                        Text("Cuando termine una escapada aparecerá aquí con vuestras puntuaciones, recuerdos y total gastado.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(24)
                } else {
                    ForEach(escapadas) { escapada in
                        NavigationLink(destination: DetalleEscapadaView(escapadaId: escapada.id)) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    Text(escapada.icono)
                                        .font(.title)
                                        .frame(width: 50, height: 50)
                                        .background(Color.crema)
                                        .cornerRadius(14)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(escapada.titulo)
                                            .font(.headline)
                                            .foregroundColor(.tinta)
                                        Text("📍 \(escapada.destino) · \(formatearRangoFechas(escapada.fechaInicio, escapada.fechaFin))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }

                                // Dinero total gastado en el viaje
                                HStack {
                                    Label("Total gastado en el viaje", systemImage: "eurosign.circle.fill")
                                        .font(.caption.bold())
                                        .foregroundColor(.tinta)
                                    Spacer()
                                    Text(formatearEuros(escapada.totalGastadoEuros))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.terracota)
                                }
                                .padding(10)
                                .background(Color.terracotaSuave.opacity(0.65))
                                .cornerRadius(12)

                                // Resumen de estrellas si ya está puntuado
                                let media = calcularMediaEstrellas(escapada.valoracion)
                                if media > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text(String(format: "Valoración media: %.1f / 5", media))
                                            .font(.caption.bold())
                                            .foregroundColor(.tinta)
                                    }
                                }

                                if !escapada.recuerdo.isEmpty {
                                    Text("\"\(escapada.recuerdo)\"")
                                        .font(.caption)
                                        .italic()
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(22)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.arena, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .background(Color.crema)
    }

    private func calcularMediaEstrellas(_ v: ValoracionViaje) -> Double {
        let valores = [v.museos, v.comida, v.ciudad, v.alojamiento, v.momentosJuntos].filter { $0 > 0 }
        guard !valores.isEmpty else { return 0 }
        let suma = valores.reduce(0, +)
        return Double(suma) / Double(valores.count)
    }
}

// ============================================================================
// MARK: - 8. DETALLE DE LA ESCAPADA
// ============================================================================

struct DetalleEscapadaView: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaId: UUID

    @State private var mostrandoNuevoVuelo = false
    @State private var mostrandoNuevoTren = false
    @State private var mostrandoNuevoAlojamiento = false
    @State private var mostrandoNuevoGasto = false

    @State private var nuevoItemCheck = ""
    @State private var asignadoCheck = "Ambos"
    @State private var nuevaIdea = ""

    private var indiceEscapada: Int? {
        store.escapadas.firstIndex(where: { $0.id == escapadaId })
    }

    var body: some View {
        Group {
            if let idx = indiceEscapada {
                let escapada = store.escapadas[idx]
                List {
                    // 1. CABECERA DEL VIAJE
                    Section {
                        HStack(spacing: 14) {
                            Text(escapada.icono)
                                .font(.system(size: 38))
                                .frame(width: 60, height: 60)
                                .background(Color.terracotaSuave)
                                .cornerRadius(16)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(escapada.titulo)
                                    .font(.title3.bold())
                                Text("📍 \(escapada.destino)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("🗓️ \(formatearRangoFechas(escapada.fechaInicio, escapada.fechaFin))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // 2. PUNTUACIÓN DEL VIAJE (1 A 5 ESTRELLAS SI YA FINALIZÓ)
                    if escapada.estaFinalizada {
                        Section("⭐ Puntuación de vuestro viaje (1 a 5)") {
                            SelectorEstrellasFila(titulo: "🏛️ Museos y cultura", valor: escapada.valoracion.museos) { nuevo in
                                var copia = escapada
                                copia.valoracion.museos = nuevo
                                store.actualizarEscapada(copia)
                            }
                            SelectorEstrellasFila(titulo: "🍝 Comida y restaurantes", valor: escapada.valoracion.comida) { nuevo in
                                var copia = escapada
                                copia.valoracion.comida = nuevo
                                store.actualizarEscapada(copia)
                            }
                            SelectorEstrellasFila(titulo: "🏙️ La ciudad y ambiente", valor: escapada.valoracion.ciudad) { nuevo in
                                var copia = escapada
                                copia.valoracion.ciudad = nuevo
                                store.actualizarEscapada(copia)
                            }
                            SelectorEstrellasFila(titulo: "🛏️ Alojamiento", valor: escapada.valoracion.alojamiento) { nuevo in
                                var copia = escapada
                                copia.valoracion.alojamiento = nuevo
                                store.actualizarEscapada(copia)
                            }
                            SelectorEstrellasFila(titulo: "💕 Momentos juntos", valor: escapada.valoracion.momentosJuntos) { nuevo in
                                var copia = escapada
                                copia.valoracion.momentosJuntos = nuevo
                                store.actualizarEscapada(copia)
                            }
                        }
                    }

                    // 3. VUELOS
                    Section {
                        ForEach(escapada.vuelos) { vuelo in
                            VueloCardView(vuelo: vuelo)
                        }
                        .onDelete { offsets in
                            var copia = escapada
                            copia.vuelos.remove(atOffsets: offsets)
                            store.actualizarEscapada(copia)
                        }

                        Button {
                            mostrandoNuevoVuelo = true
                        } label: {
                            Label("Añadir vuelo", systemImage: "airplane.circle.fill")
                                .foregroundColor(.terracota)
                                .font(.subheadline.bold())
                        }
                    } header: {
                        Text("✈️ Vuelos")
                    }

                    // 4. TRENES (OPERADORAS ESPAÑOLAS Y BILLETES)
                    Section {
                        ForEach(escapada.trenes) { tren in
                            TrenCardView(tren: tren)
                        }
                        .onDelete { offsets in
                            var copia = escapada
                            copia.trenes.remove(atOffsets: offsets)
                            store.actualizarEscapada(copia)
                        }

                        Button {
                            mostrandoNuevoTren = true
                        } label: {
                            Label("Añadir billete de tren", systemImage: "tram.circle.fill")
                                .foregroundColor(.terracota)
                                .font(.subheadline.bold())
                        }

                        // Accesos directos a páginas de trenes españolas
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Webs oficiales de trenes en España:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Link("Renfe", destination: URL(string: "https://www.renfe.com/es/es")!)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.terracotaSuave)
                                    .foregroundColor(.terracota)
                                    .cornerRadius(8)

                                Link("Iryo", destination: URL(string: "https://iryo.eu/es")!)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.terracotaSuave)
                                    .foregroundColor(.terracota)
                                    .cornerRadius(8)

                                Link("Ouigo", destination: URL(string: "https://www.ouigo.com/es")!)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.terracotaSuave)
                                    .foregroundColor(.terracota)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("🚂 Trenes")
                    }

                    // 5. MÚLTIPLES ALOJAMIENTOS
                    Section {
                        ForEach(escapada.alojamientos) { alojamiento in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(alojamiento.nombre)
                                        .font(.headline)
                                    Spacer()
                                    if !alojamiento.localizador.isEmpty {
                                        Text(alojamiento.localizador)
                                            .font(.caption.monospaced().bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.crema)
                                            .cornerRadius(6)
                                    }
                                }
                                if !alojamiento.direccion.isEmpty {
                                    Text("📍 \(alojamiento.direccion)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("🗓️ \(formatearRangoFechas(alojamiento.fechaEntrada, alojamiento.fechaSalida))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if !alojamiento.notas.isEmpty {
                                    Text(alojamiento.notas)
                                        .font(.caption)
                                        .foregroundColor(.terracota)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            var copia = escapada
                            copia.alojamientos.remove(atOffsets: offsets)
                            store.actualizarEscapada(copia)
                        }

                        Button {
                            mostrandoNuevoAlojamiento = true
                        } label: {
                            Label("Añadir alojamiento", systemImage: "bed.double.circle.fill")
                                .foregroundColor(.terracota)
                                .font(.subheadline.bold())
                        }
                    } header: {
                        Text("🏨 Alojamientos (\(escapada.alojamientos.count))")
                    }

                    // 6. GASTOS COMPARTIDOS (DIVISA ORIGINAL + CONVERSIÓN A EUROS)
                    Section {
                        let resumen = calcularTotalesGastos(escapada.gastos)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Total viaje:")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(formatearEuros(resumen.total))
                                    .font(.headline.bold())
                                    .foregroundColor(.terracota)
                            }
                            Text(resumen.balanceTexto)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        ForEach(escapada.gastos) { gasto in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(gasto.concepto)
                                        .font(.subheadline.bold())
                                    Text("Pagado por \(gasto.pagadoPor)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    if gasto.codigoDivisa != "EUR" {
                                        Text(formatearDivisa(gasto.importeOriginal, codigo: gasto.codigoDivisa))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.tinta)
                                        Text("≈ \(formatearEuros(gasto.importeEuros))")
                                            .font(.caption.bold())
                                            .foregroundColor(.terracota)
                                    } else {
                                        Text(formatearEuros(gasto.importeEuros))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.tinta)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            var copia = escapada
                            copia.gastos.remove(atOffsets: offsets)
                            store.actualizarEscapada(copia)
                        }

                        Button {
                            mostrandoNuevoGasto = true
                        } label: {
                            Label("Añadir gasto", systemImage: "plus.circle.fill")
                                .foregroundColor(.terracota)
                                .font(.subheadline.bold())
                        }
                    } header: {
                        Text("💶 Gastos compartidos")
                    }

                    // 7. NOTAS RÁPIDAS E IDEAS (DISPARA POP-UP EN EL OTRO MÓVIL AL CAMBIAR)
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas rápidas compartidas")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            TextField(
                                "Escribe una nota rápida...",
                                text: Binding(
                                    get: { escapada.notasRapidas },
                                    set: { nuevoValor in
                                        var copia = escapada
                                        copia.notasRapidas = nuevoValor
                                        store.actualizarEscapada(copia)
                                    }
                                ),
                                axis: .vertical
                            )
                            .lineLimit(2...5)
                        }

                        HStack {
                            TextField("Añadir idea o restaurante...", text: $nuevaIdea)
                            Button("Añadir") {
                                guard !nuevaIdea.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                var copia = escapada
                                copia.ideas.append(nuevaIdea.trimmingCharacters(in: .whitespaces))
                                store.actualizarEscapada(copia)
                                nuevaIdea = ""
                            }
                            .bold()
                            .foregroundColor(.terracota)
                        }

                        ForEach(Array(escapada.ideas.enumerated()), id: \.offset) { index, idea in
                            Text("💡 \(idea)")
                                .font(.subheadline)
                        }
                        .onDelete { offsets in
                            var copia = escapada
                            copia.ideas.remove(atOffsets: offsets)
                            store.actualizarEscapada(copia)
                        }
                    } header: {
                        Text("📝 Notas rápidas e ideas")
                    }

                    // 8. CHECKLIST COMPARTIDA
                    Section {
                        HStack {
                            TextField("Añadir cosa a la maleta...", text: $nuevoItemCheck)
                            Picker("", selection: $asignadoCheck) {
                                Text("Ambos").tag("Ambos")
                                Text("Yo").tag("Yo")
                                Text("Tú").tag("Tú")
                            }
                            .labelsHidden()
                            Button("+") {
                                guard !nuevoItemCheck.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                var copia = escapada
                                copia.checklist.append(
                                    ItemChecklist(
                                        texto: nuevoItemCheck.trimmingCharacters(in: .whitespaces),
                                        completado: false,
                                        asignadoA: asignadoCheck
                                    )
                                )
                                store.actualizarEscapada(copia)
                                nuevoItemCheck = ""
                            }
                            .bold()
                            .foregroundColor(.terracota)
                        }

                        ForEach(escapada.checklist) { item in
                            Button {
                                var copia = escapada
                                if let i = copia.checklist.firstIndex(where: { $0.id == item.id }) {
                                    copia.checklist[i].completado.toggle()
                                    store.actualizarEscapada(copia)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: item.completado ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.completado ? .terracota : .gray)
                                    Text(item.texto)
                                        .strikethrough(item.completado)
                                        .foregroundColor(item.completado ? .secondary : .primary)
                                    Spacer()
                                    Text(item.asignadoA)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.crema)
                                        .cornerRadius(6)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            var copia = escapada
                            copia.checklist.remove(atOffsets: offsets)
                            store.actualizarEscapada(copia)
                        }
                    } header: {
                        Text("🧳 Checklist")
                    }

                    // 9. RECUERDO DEL VIAJE
                    Section("💌 Nuestro recuerdo") {
                        TextField(
                            "Escribe aquí lo mejor de esta escapada...",
                            text: Binding(
                                get: { escapada.recuerdo },
                                set: { nuevo in
                                    var copia = escapada
                                    copia.recuerdo = nuevo
                                    store.actualizarEscapada(copia)
                                }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                    }

                    // 10. ELIMINAR ESCAPADA
                    Section {
                        Button(role: .destructive) {
                            store.eliminarEscapada(escapada.id)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Eliminar escapada", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle(escapada.titulo)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $mostrandoNuevoVuelo) {
                    AgregarVueloSheet(escapadaId: escapada.id)
                }
                .sheet(isPresented: $mostrandoNuevoTren) {
                    AgregarTrenSheet(escapadaId: escapada.id)
                }
                .sheet(isPresented: $mostrandoNuevoAlojamiento) {
                    AgregarAlojamientoSheet(escapadaId: escapada.id)
                }
                .sheet(isPresented: $mostrandoNuevoGasto) {
                    AgregarGastoSheet(escapadaId: escapada.id)
                }
            } else {
                Text("Escapada no encontrada")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// ============================================================================
// MARK: - 9. COMPONENTES VISUALES AUXILIARES
// ============================================================================

struct SelectorEstrellasFila: View {
    let titulo: String
    let valor: Int
    let onSeleccionar: (Int) -> Void

    var body: some View {
        HStack {
            Text(titulo)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { estrella in
                    Button {
                        onSeleccionar(estrella)
                    } label: {
                        Image(systemName: estrella <= valor ? "star.fill" : "star")
                            .foregroundColor(estrella <= valor ? .orange : .gray.opacity(0.4))
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct VueloCardView: View {
    let vuelo: Vuelo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vuelo.trayecto.uppercased())
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.terracotaSuave)
                    .foregroundColor(.terracota)
                    .cornerRadius(6)
                Text("\(vuelo.aerolinea) · \(vuelo.numeroVuelo)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if !vuelo.localizador.isEmpty {
                    Text(vuelo.localizador)
                        .font(.caption.monospaced().bold())
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text(vuelo.origen)
                        .font(.title3.bold())
                    Text(formatearHora(vuelo.fechaHoraSalida))
                        .font(.caption)
                        .foregroundColor(.terracota)
                }
                Spacer()
                Image(systemName: "airplane")
                    .foregroundColor(.terracota)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(vuelo.destino)
                        .font(.title3.bold())
                    Text(formatearHora(vuelo.fechaHoraLlegada))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TrenCardView: View {
    let tren: TrenViaje

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tren.trayecto.uppercased())
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.terracotaSuave)
                    .foregroundColor(.terracota)
                    .cornerRadius(6)
                Text(tren.operadora)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if !tren.localizador.isEmpty {
                    Text(tren.localizador)
                        .font(.caption.monospaced().bold())
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text(tren.estacionOrigen)
                        .font(.subheadline.bold())
                    Text(formatearHora(tren.fechaHoraSalida))
                        .font(.caption)
                        .foregroundColor(.terracota)
                }
                Spacer()
                Image(systemName: "tram.fill")
                    .foregroundColor(.terracota)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(tren.estacionDestino)
                        .font(.subheadline.bold())
                    Text(formatearHora(tren.fechaHoraLlegada))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// ============================================================================
// MARK: - 10. MODALES DE CREACIÓN (ESCAPADA, VUELO, TREN, ALOJAMIENTO, GASTO)
// ============================================================================

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

    // Opción 1: Vuelos
    @State private var tieneVuelos = false
    @State private var aerolineaVuelo = ""
    @State private var numeroVuelo = ""
    @State private var origenVuelo = ""
    @State private var destinoVuelo = ""
    @State private var localizadorVuelo = ""
    @State private var horaSalidaVuelo = Date()

    // Opción 2: Trenes (independiente de vuelos)
    @State private var tieneTrenes = false
    @State private var operadoraTren = "Renfe"
    @State private var origenTren = ""
    @State private var destinoTren = ""
    @State private var localizadorTren = ""

    let iconos = ["✈️", "🚂", "🏔️", "🏖️", "🍷", "🎁", "🚗", "🏙️", "🌿", "🍝"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos principales") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(iconos, id: \.self) { item in
                                Button {
                                    icono = item
                                } label: {
                                    Text(item)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(icono == item ? Color.terracotaSuave : Color.crema)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(icono == item ? Color.terracota : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("Nombre del plan (ej: Escapada a Roma)", text: $titulo)
                    TextField("Destino (ej: Roma)", text: $destino)
                    DatePicker("Fecha de ida", selection: $fechaInicio, displayedComponents: .date)
                    DatePicker("Fecha de vuelta", selection: $fechaFin, in: fechaInicio..., displayedComponents: .date)
                }

                // INTERRUPTOR INDEPENDIENTE DE VUELOS
                Section("✈️ Transporte aéreo (opcional)") {
                    Toggle("¿Este viaje incluye vuelos?", isOn: $tieneVuelos)
                    if tieneVuelos {
                        TextField("Aerolínea (ej: Iberia)", text: $aerolineaVuelo)
                        TextField("Nº vuelo (ej: IB3140)", text: $numeroVuelo)
                            .textInputAutocapitalization(.characters)
                        HStack {
                            TextField("Origen (MAD)", text: $origenVuelo)
                                .textInputAutocapitalization(.characters)
                            TextField("Destino (FCO)", text: $destinoVuelo)
                                .textInputAutocapitalization(.characters)
                        }
                        TextField("Localizador", text: $localizadorVuelo)
                            .textInputAutocapitalization(.characters)
                        DatePicker("Hora de salida", selection: $horaSalidaVuelo, displayedComponents: .hourAndMinute)
                    }
                }

                // INTERRUPTOR INDEPENDIENTE DE TRENES ESPAÑOLES
                Section("🚂 Transporte en tren (opcional)") {
                    Toggle("¿Este viaje incluye trenes?", isOn: $tieneTrenes)
                    if tieneTrenes {
                        Picker("Operadora española", selection: $operadoraTren) {
                            Text("Renfe (AVE / Avlo / Alvia)").tag("Renfe")
                            Text("Iryo").tag("Iryo")
                            Text("Ouigo España").tag("Ouigo")
                        }
                        TextField("Estación origen (ej: Madrid Atocha)", text: $origenTren)
                        TextField("Estación destino (ej: Barcelona Sants)", text: $destinoTren)
                        TextField("Localizador billete", text: $localizadorTren)
                            .textInputAutocapitalization(.characters)

                        HStack(spacing: 10) {
                            Link("Web Renfe", destination: URL(string: "https://www.renfe.com/es/es")!)
                            Text("·")
                            Link("Web Iryo", destination: URL(string: "https://iryo.eu/es")!)
                            Text("·")
                            Link("Web Ouigo", destination: URL(string: "https://www.ouigo.com/es")!)
                        }
                        .font(.caption.bold())
                        .foregroundColor(.terracota)
                    }
                }

                Section("🎁 Modo sorpresa") {
                    Toggle("Ocultar destino hasta el viaje", isOn: $esSorpresa)
                    if esSorpresa {
                        TextField("Pista para tu pareja", text: $pistaSorpresa)
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
                        guardarNuevaEscapada()
                    }
                    .bold()
                    .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty || destino.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func guardarNuevaEscapada() {
        let cal = Calendar.current
        let compsHora = cal.dateComponents([.hour, .minute], from: horaSalidaVuelo)
        let fechaSalidaCompleta = cal.date(
            bySettingHour: compsHora.hour ?? 9,
            minute: compsHora.minute ?? 0,
            second: 0,
            of: fechaInicio
        ) ?? fechaInicio

        let vuelosIniciales: [Vuelo] = (tieneVuelos && (!origenVuelo.isEmpty || !destinoVuelo.isEmpty || !numeroVuelo.isEmpty || !localizadorVuelo.isEmpty)) ? [
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
                urlReserva: ""
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
            titulo: titulo.trimmingCharacters(in: .whitespaces),
            destino: destino.trimmingCharacters(in: .whitespaces),
            fechaInicio: fechaInicio,
            fechaFin: fechaFin,
            icono: icono,
            tieneVuelos: tieneVuelos,
            tieneTrenes: tieneTrenes,
            esSorpresa: esSorpresa,
            pistaSorpresa: pistaSorpresa,
            diasRevelarSorpresaAntes: diasRevelarAntes,
            vuelos: vuelosIniciales,
            trenes: trenesIniciales,
            checklist: [
                ItemChecklist(texto: "DNI / Pasaportes", completado: false, asignadoA: "Ambos"),
                ItemChecklist(texto: "Cargadores", completado: false, asignadoA: "Ambos")
            ]
        )
        store.agregarEscapada(nueva)
        dismiss()
    }
}

struct AgregarVueloSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaId: UUID

    @State private var trayecto = "Ida"
    @State private var origen = ""
    @State private var destino = ""
    @State private var aerolinea = ""
    @State private var numeroVuelo = ""
    @State private var localizador = ""
    @State private var salida = Date()
    @State private var llegada = Date().addingTimeInterval(7200)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Trayecto", selection: $trayecto) {
                    Text("Ida").tag("Ida")
                    Text("Vuelta").tag("Vuelta")
                    Text("Escala").tag("Escala")
                }
                TextField("Aerolínea (ej: Iberia)", text: $aerolinea)
                TextField("Nº vuelo (ej: IB3140)", text: $numeroVuelo)
                    .textInputAutocapitalization(.characters)
                TextField("Origen IATA (ej: MAD)", text: $origen)
                    .textInputAutocapitalization(.characters)
                TextField("Destino IATA (ej: PRG)", text: $destino)
                    .textInputAutocapitalization(.characters)
                TextField("Localizador", text: $localizador)
                    .textInputAutocapitalization(.characters)
                DatePicker("Salida", selection: $salida)
                DatePicker("Llegada", selection: $llegada)
            }
            .navigationTitle("Añadir vuelo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if var escapada = store.escapadas.first(where: { $0.id == escapadaId }) {
                            escapada.vuelos.append(
                                Vuelo(
                                    trayecto: trayecto,
                                    origen: origen.uppercased(),
                                    destino: destino.uppercased(),
                                    fechaHoraSalida: salida,
                                    fechaHoraLlegada: llegada,
                                    aerolinea: aerolinea,
                                    numeroVuelo: numeroVuelo.uppercased(),
                                    localizador: localizador.uppercased(),
                                    terminalPuerta: "",
                                    urlReserva: ""
                                )
                            )
                            store.actualizarEscapada(escapada)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(origen.isEmpty || destino.isEmpty)
                }
            }
        }
    }
}

struct AgregarTrenSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaId: UUID

    @State private var trayecto = "Ida"
    @State private var operadora = "Renfe"
    @State private var estacionOrigen = ""
    @State private var estacionDestino = ""
    @State private var localizador = ""
    @State private var salida = Date()
    @State private var llegada = Date().addingTimeInterval(9000)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Trayecto", selection: $trayecto) {
                    Text("Ida").tag("Ida")
                    Text("Vuelta").tag("Vuelta")
                }
                Picker("Operadora española", selection: $operadora) {
                    Text("Renfe").tag("Renfe")
                    Text("Iryo").tag("Iryo")
                    Text("Ouigo").tag("Ouigo")
                }
                TextField("Estación origen (ej: Madrid Atocha)", text: $estacionOrigen)
                TextField("Estación destino (ej: Valencia Joaquín Sorolla)", text: $estacionDestino)
                TextField("Localizador", text: $localizador)
                    .textInputAutocapitalization(.characters)
                DatePicker("Salida", selection: $salida)
                DatePicker("Llegada", selection: $llegada)
            }
            .navigationTitle("Añadir tren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if var escapada = store.escapadas.first(where: { $0.id == escapadaId }) {
                            escapada.trenes.append(
                                TrenViaje(
                                    trayecto: trayecto,
                                    operadora: operadora,
                                    estacionOrigen: estacionOrigen,
                                    estacionDestino: estacionDestino,
                                    fechaHoraSalida: salida,
                                    fechaHoraLlegada: llegada,
                                    localizador: localizador.uppercased()
                                )
                            )
                            store.actualizarEscapada(escapada)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(estacionOrigen.isEmpty || estacionDestino.isEmpty)
                }
            }
        }
    }
}

struct AgregarAlojamientoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaId: UUID

    @State private var nombre = ""
    @State private var direccion = ""
    @State private var localizador = ""
    @State private var fechaEntrada = Date()
    @State private var fechaSalida = Date().addingTimeInterval(86400 * 2)
    @State private var notas = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre del hotel o apartamento", text: $nombre)
                TextField("Dirección", text: $direccion)
                TextField("Localizador / Reserva", text: $localizador)
                DatePicker("Entrada", selection: $fechaEntrada, displayedComponents: .date)
                DatePicker("Salida", selection: $fechaSalida, in: fechaEntrada..., displayedComponents: .date)
                TextField("Notas (check-in, código puerta...)", text: $notas)
            }
            .navigationTitle("Nuevo alojamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if var escapada = store.escapadas.first(where: { $0.id == escapadaId }) {
                            escapada.alojamientos.append(
                                AlojamientoItem(
                                    nombre: nombre,
                                    direccion: direccion,
                                    fechaEntrada: fechaEntrada,
                                    fechaSalida: fechaSalida,
                                    localizador: localizador,
                                    notas: notas
                                )
                            )
                            store.actualizarEscapada(escapada)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct AgregarGastoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapadaId: UUID

    @State private var concepto = ""
    @State private var importeTexto = ""
    @State private var divisaSeleccionada: DivisaInfo = DIVISAS_DISPONIBLES[0]
    @State private var pagadoPor = "Yo"

    var importeNumerico: Double {
        Double(importeTexto.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var equivalenteEuros: Double {
        importeNumerico * divisaSeleccionada.tasaAEuros
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle del gasto") {
                    TextField("Concepto (ej: Cena, entradas museo...)", text: $concepto)

                    Picker("Moneda pagada", selection: $divisaSeleccionada) {
                        ForEach(DIVISAS_DISPONIBLES) { d in
                            Text("\(d.id) - \(d.nombre) (\(d.simbolo))").tag(d)
                        }
                    }

                    TextField("Importe en \(divisaSeleccionada.id)", text: $importeTexto)
                        .keyboardType(.decimalPad)

                    if divisaSeleccionada.id != "EUR" && importeNumerico > 0 {
                        HStack {
                            Text("Conversión a Euros:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(formatearDivisa(importeNumerico, codigo: divisaSeleccionada.id)) = \(formatearEuros(equivalenteEuros))")
                                .font(.caption.bold())
                                .foregroundColor(.terracota)
                        }
                    }

                    Picker("Pagado por", selection: $pagadoPor) {
                        Text("Yo").tag("Yo")
                        Text("Tú").tag("Tú")
                        Text("Ambos (50/50)").tag("Ambos")
                    }
                }
            }
            .navigationTitle("Añadir gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if var escapada = store.escapadas.first(where: { $0.id == escapadaId }), importeNumerico > 0 {
                            escapada.gastos.append(
                                GastoViaje(
                                    concepto: concepto.trimmingCharacters(in: .whitespaces),
                                    importeOriginal: importeNumerico,
                                    codigoDivisa: divisaSeleccionada.id,
                                    importeEuros: equivalenteEuros,
                                    pagadoPor: pagadoPor
                                )
                            )
                            store.actualizarEscapada(escapada)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(concepto.trimmingCharacters(in: .whitespaces).isEmpty || importeNumerico <= 0)
                }
            }
        }
    }
}

struct SincronizacionParejaSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    @State private var nuevoCodigoInput = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Vuestro código compartido actual") {
                    HStack {
                        Text(store.codigoPareja)
                            .font(.title3.monospaced().bold())
                            .foregroundColor(.terracota)
                        Spacer()
                        Button("Copiar") {
                            UIPasteboard.general.string = store.codigoPareja
                        }
                        .font(.caption.bold())
                    }
                    Text("Introducid este mismo código en ambos iPhone para sincronizar vuestros viajes y recibir avisos en tiempo real.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Conectar con otro código") {
                    TextField("Ej: VIAJE-2026", text: $nuevoCodigoInput)
                        .textInputAutocapitalization(.characters)
                    Button("Conectar a este espacio") {
                        store.cambiarCodigoPareja(nuevoCodigoInput)
                        dismiss()
                    }
                    .bold()
                    .disabled(nuevoCodigoInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section {
                    Button("Generar nuevo código aleatorio") {
                        store.crearNuevoCodigoPareja()
                    }
                }
            }
            .navigationTitle("Sincronizar iPhones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

// ============================================================================
// MARK: - 11. FUNCIONES AUXILIARES DE CÁLCULO Y FORMATO
// ============================================================================

func calcularTotalesGastos(_ gastos: [GastoViaje]) -> (total: Double, balanceTexto: String) {
    let total = gastos.reduce(0) { $0 + $1.importeEuros }
    let pagadoYo = gastos.filter { $0.pagadoPor == "Yo" }.reduce(0) { $0 + $1.importeEuros }
    let pagadoTu = gastos.filter { $0.pagadoPor == "Tú" }.reduce(0) { $0 + $1.importeEuros }

    let diferencia = (pagadoYo - pagadoTu) / 2.0
    if abs(diferencia) < 0.05 {
        return (total, "Cuentas cuadradas al 50% ✨")
    } else if diferencia > 0 {
        return (total, "Tú debes a Yo \(formatearEuros(diferencia)) para igualar")
    } else {
        return (total, "Yo debe a Tú \(formatearEuros(abs(diferencia))) para igualar")
    }
}

func formatearEuros(_ valor: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "EUR"
    formatter.locale = Locale(identifier: "es_ES")
    return formatter.string(from: NSNumber(value: valor)) ?? String(format: "%.2f €", valor)
}

func formatearDivisa(_ valor: Double, codigo: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.locale = Locale(identifier: "es_ES")
    let numStr = formatter.string(from: NSNumber(value: valor)) ?? String(format: "%.2f", valor)
    return "\(numStr) \(codigo)"
}

func formatearRangoFechas(_ inicio: Date, _ fin: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "es_ES")
    df.dateFormat = "d MMM"
    let s1 = df.string(from: inicio)
    let s2 = df.string(from: fin)
    return s1 == s2 ? s1 : "\(s1) – \(s2)"
}

func formatearHora(_ fecha: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "HH:mm"
    return df.string(from: fecha)
}