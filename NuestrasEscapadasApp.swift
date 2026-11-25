import SwiftUI
import FirebaseCore
import FirebaseFirestore
import MapKit
import UserNotifications
import PhotosUI

// ============================================================================
// 0. MODELOS DE DATOS Y SERVICIOS DE TRANSPORTE (VUELOS Y TRENES ESPAÑA)
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

struct BilleteTren: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var operador: String
    var trayecto: String
    var estacionOrigen: String
    var estacionDestino: String
    var fechaHoraSalida: Date
    var fechaHoraLlegada: Date
    var numeroTren: String
    var localizador: String
    var cocheAsiento: String
    var urlReserva: String
}

struct OperadorTrenEspana: Identifiable, Hashable {
    let id: String
    let nombre: String
    let descripcion: String
    let urlWeb: String
}

enum TrenesEspana {
    static let operadores: [OperadorTrenEspana] = [
        OperadorTrenEspana(id: "renfe", nombre: "Renfe", descripcion: "AVE, Avlo, Alvia, Media Distancia", urlWeb: "https://www.renfe.com/es/es"),
        OperadorTrenEspana(id: "iryo", nombre: "iryo", descripcion: "Alta velocidad España", urlWeb: "https://iryo.eu/es/home"),
        OperadorTrenEspana(id: "ouigo", nombre: "OUIGO", descripcion: "Alta velocidad bajo coste", urlWeb: "https://www.ouigo.com/es"),
        OperadorTrenEspana(id: "trainline", nombre: "Trainline", descripcion: "Comparador Renfe, iryo y OUIGO", urlWeb: "https://www.thetrainline.com/es")
    ]

    static func urlParaOperador(_ nombre: String) -> String {
        operadores.first(where: { $0.nombre.caseInsensitiveCompare(nombre) == .orderedSame })?.urlWeb ?? "https://www.renfe.com/es/es"
    }
}

struct ResultadoBusquedaVuelo {
    let origen: String
    let destino: String
    let aerolinea: String
    let terminal: String
    let urlReserva: String
    let urlEstadoWeb: String
    let duracionMin: Int
    let fuente: String
}

enum BuscadorVuelosWeb {
    static func buscar(
        numeroVuelo: String,
        localizador: String,
        fechaSalida: Date,
        trayecto: String,
        destinoViaje: String
    ) async -> ResultadoBusquedaVuelo? {
        let num = numeroVuelo.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let prefijo = String(num.prefix(2))

        let aerolineas: [String: (nombre: String, web: String)] = [
            "IB": ("Iberia", "https://www.iberia.com/es/gestion-reservas/"),
            "VY": ("Vueling", "https://www.vueling.com/es/gestiona-tu-reserva"),
            "FR": ("Ryanair", "https://www.ryanair.com/es/es/mybookings"),
            "UX": ("Air Europa", "https://www.aireuropa.com/es/es/aea/gestiona-tu-reserva.html"),
            "U2": ("easyJet", "https://www.easyjet.com/es/manage-bookings"),
            "LH": ("Lufthansa", "https://www.lufthansa.com/es/es/my-bookings"),
            "AF": ("Air France", "https://wwws.airfrance.es/trip"),
            "BA": ("British Airways", "https://www.britishairways.com/travel/managebooking/public/es_es")
        ]

        let rutasConocidas: [String: (origen: String, destino: String, terminal: String, min: Int)] = [
            "IB3140": ("MAD", "PRG", "Terminal 4", 175),
            "IB3141": ("PRG", "MAD", "Terminal 2", 180),
            "FR2418": ("KRK", "MAD", "Terminal 1", 215),
            "VY1002": ("BCN", "FCO", "Terminal 1", 110),
            "UX1093": ("MAD", "ORY", "Terminal 2", 125)
        ]

        let infoAerolinea = aerolineas[prefijo] ?? ("Aerolínea", "")
        let urlTracking = num.isEmpty ? "" : "https://www.flightradar24.com/data/flights/\(num.lowercased())"

        if let conocida = rutasConocidas[num] {
            return ResultadoBusquedaVuelo(
                origen: conocida.origen,
                destino: conocida.destino,
                aerolinea: infoAerolinea.nombre,
                terminal: conocida.terminal,
                urlReserva: infoAerolinea.web,
                urlEstadoWeb: urlTracking,
                duracionMin: conocida.min,
                fuente: "Ruta verificada"
            )
        }

        let iataDestino = inferirIATA(desde: destinoViaje)
        if !num.isEmpty || !localizador.trimmingCharacters(in: .whitespaces).isEmpty {
            let esVuelta = trayecto == "Vuelta"
            return ResultadoBusquedaVuelo(
                origen: esVuelta ? iataDestino : "MAD",
                destino: esVuelta ? "MAD" : iataDestino,
                aerolinea: infoAerolinea.nombre,
                terminal: "",
                urlReserva: infoAerolinea.web,
                urlEstadoWeb: urlTracking,
                duracionMin: 150,
                fuente: "Asistente de rutas"
            )
        }
        return nil
    }

    private static func inferirIATA(desde texto: String) -> String {
        let lower = texto.lowercased()
        let mapa: [(String, String)] = [
            ("praga", "PRG"), ("roma", "FCO"), ("paris", "CDG"), ("parís", "CDG"),
            ("londres", "LHR"), ("lisboa", "LIS"), ("oporto", "OPO"), ("cracovia", "KRK"),
            ("amsterdam", "AMS"), ("ámsterdam", "AMS"), ("viena", "VIE"), ("budapest", "BUD"),
            ("berlin", "BER"), ("berlín", "BER"), ("milan", "MXP"), ("milán", "MXP"),
            ("barcelona", "BCN"), ("sevilla", "SVQ"), ("mallorca", "PMI"), ("tenerife", "TFN"),
            ("nueva york", "JFK"), ("tokio", "HND"), ("tokyo", "HND")
        ]
        for (ciudad, codigo) in mapa where lower.contains(ciudad) {
            return codigo
        }
        return "DEST"
    }
}

struct AlojamientoInfo: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var nombre: String = ""
    var direccion: String = ""
    var horaCheckIn: String = "15:00"
    var horaCheckOut: String = "11:00"
    var codigoReserva: String = ""
    var urlReserva: String = ""

    var tieneDatos: Bool {
        !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !direccion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !codigoReserva.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !urlReserva.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ItemChecklist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var texto: String
    var completado: Bool = false
    var asignadoA: String = "Ambos"
}

struct RetoFotografico: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var titulo: String
    var completado: Bool = false
    var fotoBase64: String? = nil
}

struct ActividadDia: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var diaIndex: Int
    var nombreSitio: String
    var urlSitio: String = ""
}

struct GastoViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var concepto: String
    var importe: Double
    var importeOriginal: Double? = nil
    var monedaCodigo: String? = nil
    var tasaCambioAEuro: Double? = nil
    var pagadoPor: String
    var categoria: String

    var monedaEfectiva: String {
        let code = (monedaCodigo ?? "EUR").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return code.isEmpty ? "EUR" : code
    }

    var importeOriginalEfectivo: Double {
        importeOriginal ?? importe
    }
}

struct ValoracionEscapada: Codable, Hashable {
    var general: Int = 0
    var alojamiento: Int = 0
    var comida: Int = 0
    var planes: Int = 0

    var mediaEstrellas: Double? {
        let puntuaciones = [general, alojamiento, comida, planes].filter { $0 > 0 }
        guard !puntuaciones.isEmpty else { return nil }
        let suma = puntuaciones.reduce(0, +)
        return Double(suma) / Double(puntuaciones.count)
    }
}

struct DestinoWishlist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var nombreDestino: String
    var paisORegion: String = ""
    var categoria: String = "Ciudad"
    var temporadaIdeal: String = "Cualquier época"
    var notaOEnlace: String = ""
    var icono: String = "✨"
    var prioridadAlta: Bool = true
    var fechaAgregado: Date = Date()
}

struct Escapada: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var titulo: String
    var destino: String
    var fechaInicio: Date
    var fechaFin: Date
    var icono: String = "✈️"
    var tieneVuelos: Bool = false
    var tieneTrenes: Bool = false
    var esSorpresa: Bool = false
    var pistaSorpresa: String = ""
    var diasRevelarSorpresaAntes: Int = 0
    var recuerdo: String = ""
    var alojamiento: AlojamientoInfo = AlojamientoInfo()
    var alojamientos: [AlojamientoInfo] = []
    var vuelos: [Vuelo] = []
    var trenes: [BilleteTren] = []
    var checklist: [ItemChecklist] = []
    var retosFotograficos: [RetoFotografico] = []
    var itinerario: [ActividadDia] = []
    var gastos: [GastoViaje] = []
    var valoracion: ValoracionEscapada = ValoracionEscapada()
    var ideas: [String] = []

    var todosLosAlojamientos: [AlojamientoInfo] {
        var lista: [AlojamientoInfo] = []
        if alojamiento.tieneDatos {
            lista.append(alojamiento)
        }
        lista.append(contentsOf: alojamientos.filter { $0.tieneDatos })
        return lista
    }

    var yaVivida: Bool {
        let cal = Calendar.current
        let finDia = cal.startOfDay(for: max(fechaInicio, fechaFin))
        let diaSiguiente = cal.date(byAdding: .day, value: 1, to: finDia) ?? finDia
        return Date() >= diaSiguiente
    }

    var sorpresaDesbloqueada: Bool {
        guard esSorpresa else { return true }
        let cal = Calendar.current
        let inicioDia = cal.startOfDay(for: fechaInicio)
        let fechaRevelacion = cal.date(byAdding: .day, value: -max(0, diasRevelarSorpresaAntes), to: inicioDia) ?? inicioDia
        return Date() >= fechaRevelacion
    }

    var totalDias: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: fechaInicio)
        let end = cal.startOfDay(for: max(fechaInicio, fechaFin))
        let comps = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, comps + 1)
    }

    var progresoChecklist: Double {
        guard !checklist.isEmpty else { return 0 }
        let hechos = checklist.filter { $0.completado }.count
        return Double(hechos) / Double(checklist.count)
    }
}

// ============================================================================
// 1. DIVISAS DE EUROPA, AMÉRICA Y ASIA + MODELO DE DATOS
// ============================================================================

struct DivisaInfo: Identifiable, Hashable {
    let id: String              // Código ISO: "EUR", "USD", "JPY", etc.
    let nombre: String          // Nombre legible
    let simbolo: String         // "€", "$", "¥", etc.
    let region: String          // "Europa", "América", "Asia"
    let tasaAEuro: Double       // 1 unidad de esta divisa = X euros (respaldo si no hay red)
}

enum CatalogoDivisas {
    static let todas: [DivisaInfo] = [
        // EUROPA
        DivisaInfo(id: "EUR", nombre: "Euro", simbolo: "€", region: "Europa", tasaAEuro: 1.0),
        DivisaInfo(id: "GBP", nombre: "Libra esterlina", simbolo: "£", region: "Europa", tasaAEuro: 1.18),
        DivisaInfo(id: "CHF", nombre: "Franco suizo", simbolo: "CHF", region: "Europa", tasaAEuro: 1.05),
        DivisaInfo(id: "CZK", nombre: "Corona checa", simbolo: "Kč", region: "Europa", tasaAEuro: 0.040),
        DivisaInfo(id: "PLN", nombre: "Zloty polaco", simbolo: "zł", region: "Europa", tasaAEuro: 0.23),
        DivisaInfo(id: "HUF", nombre: "Florín húngaro", simbolo: "Ft", region: "Europa", tasaAEuro: 0.0025),
        DivisaInfo(id: "RON", nombre: "Leu rumano", simbolo: "lei", region: "Europa", tasaAEuro: 0.20),
        DivisaInfo(id: "BGN", nombre: "Lev búlgaro", simbolo: "лв", region: "Europa", tasaAEuro: 0.51),
        DivisaInfo(id: "SEK", nombre: "Corona sueca", simbolo: "kr", region: "Europa", tasaAEuro: 0.088),
        DivisaInfo(id: "NOK", nombre: "Corona noruega", simbolo: "kr", region: "Europa", tasaAEuro: 0.086),
        DivisaInfo(id: "DKK", nombre: "Corona danesa", simbolo: "kr", region: "Europa", tasaAEuro: 0.134),
        DivisaInfo(id: "ISK", nombre: "Corona islandesa", simbolo: "kr", region: "Europa", tasaAEuro: 0.0067),
        DivisaInfo(id: "RSD", nombre: "Dinar serbio", simbolo: "дин", region: "Europa", tasaAEuro: 0.0085),
        DivisaInfo(id: "BAM", nombre: "Marco convertible", simbolo: "KM", region: "Europa", tasaAEuro: 0.51),
        DivisaInfo(id: "ALL", nombre: "Lek albanés", simbolo: "L", region: "Europa", tasaAEuro: 0.010),
        DivisaInfo(id: "MKD", nombre: "Denar macedonio", simbolo: "ден", region: "Europa", tasaAEuro: 0.016),
        DivisaInfo(id: "MDL", nombre: "Leu moldavo", simbolo: "L", region: "Europa", tasaAEuro: 0.052),
        DivisaInfo(id: "UAH", nombre: "Grivna ucraniana", simbolo: "₴", region: "Europa", tasaAEuro: 0.022),
        DivisaInfo(id: "TRY", nombre: "Lira turca", simbolo: "₺", region: "Europa", tasaAEuro: 0.027),
        DivisaInfo(id: "GEL", nombre: "Lari georgiano", simbolo: "₾", region: "Europa", tasaAEuro: 0.34),

        // AMÉRICA
        DivisaInfo(id: "USD", nombre: "Dólar estadounidense", simbolo: "$", region: "América", tasaAEuro: 0.92),
        DivisaInfo(id: "CAD", nombre: "Dólar canadiense", simbolo: "C$", region: "América", tasaAEuro: 0.67),
        DivisaInfo(id: "MXN", nombre: "Peso mexicano", simbolo: "$", region: "América", tasaAEuro: 0.048),
        DivisaInfo(id: "BRL", nombre: "Real brasileño", simbolo: "R$", region: "América", tasaAEuro: 0.16),
        DivisaInfo(id: "ARS", nombre: "Peso argentino", simbolo: "$", region: "América", tasaAEuro: 0.00095),
        DivisaInfo(id: "CLP", nombre: "Peso chileno", simbolo: "$", region: "América", tasaAEuro: 0.00096),
        DivisaInfo(id: "COP", nombre: "Peso colombiano", simbolo: "$", region: "América", tasaAEuro: 0.00022),
        DivisaInfo(id: "PEN", nombre: "Sol peruano", simbolo: "S/", region: "América", tasaAEuro: 0.25),
        DivisaInfo(id: "UYU", nombre: "Peso uruguayo", simbolo: "$U", region: "América", tasaAEuro: 0.022),
        DivisaInfo(id: "PYG", nombre: "Guaraní paraguayo", simbolo: "₲", region: "América", tasaAEuro: 0.00012),
        DivisaInfo(id: "BOB", nombre: "Boliviano", simbolo: "Bs", region: "América", tasaAEuro: 0.13),
        DivisaInfo(id: "VES", nombre: "Bolívar venezolano", simbolo: "Bs.D", region: "América", tasaAEuro: 0.020),
        DivisaInfo(id: "CRC", nombre: "Colón costarricense", simbolo: "₡", region: "América", tasaAEuro: 0.0018),
        DivisaInfo(id: "GTQ", nombre: "Quetzal guatemalteco", simbolo: "Q", region: "América", tasaAEuro: 0.12),
        DivisaInfo(id: "HNL", nombre: "Lempira hondureño", simbolo: "L", region: "América", tasaAEuro: 0.037),
        DivisaInfo(id: "NIO", nombre: "Córdoba nicaragüense", simbolo: "C$", region: "América", tasaAEuro: 0.025),
        DivisaInfo(id: "PAB", nombre: "Balboa panameño", simbolo: "B/.", region: "América", tasaAEuro: 0.92),
        DivisaInfo(id: "DOP", nombre: "Peso dominicano", simbolo: "RD$", region: "América", tasaAEuro: 0.015),
        DivisaInfo(id: "CUP", nombre: "Peso cubano", simbolo: "$", region: "América", tasaAEuro: 0.038),

        // ASIA
        DivisaInfo(id: "JPY", nombre: "Yen japonés", simbolo: "¥", region: "Asia", tasaAEuro: 0.0061),
        DivisaInfo(id: "CNY", nombre: "Yuan chino", simbolo: "¥", region: "Asia", tasaAEuro: 0.127),
        DivisaInfo(id: "KRW", nombre: "Won surcoreano", simbolo: "₩", region: "Asia", tasaAEuro: 0.00067),
        DivisaInfo(id: "INR", nombre: "Rupia india", simbolo: "₹", region: "Asia", tasaAEuro: 0.011),
        DivisaInfo(id: "THB", nombre: "Baht tailandés", simbolo: "฿", region: "Asia", tasaAEuro: 0.026),
        DivisaInfo(id: "VND", nombre: "Dong vietnamita", simbolo: "₫", region: "Asia", tasaAEuro: 0.000036),
        DivisaInfo(id: "IDR", nombre: "Rupia indonesia", simbolo: "Rp", region: "Asia", tasaAEuro: 0.000058),
        DivisaInfo(id: "MYR", nombre: "Ringgit malasio", simbolo: "RM", region: "Asia", tasaAEuro: 0.21),
        DivisaInfo(id: "SGD", nombre: "Dólar de Singapur", simbolo: "S$", region: "Asia", tasaAEuro: 0.69),
        DivisaInfo(id: "PHP", nombre: "Peso filipino", simbolo: "₱", region: "Asia", tasaAEuro: 0.016),
        DivisaInfo(id: "TWD", nombre: "Nuevo dólar taiwanés", simbolo: "NT$", region: "Asia", tasaAEuro: 0.028),
        DivisaInfo(id: "HKD", nombre: "Dólar de Hong Kong", simbolo: "HK$", region: "Asia", tasaAEuro: 0.118),
        DivisaInfo(id: "AED", nombre: "Dírham de EAU", simbolo: "AED", region: "Asia", tasaAEuro: 0.25),
        DivisaInfo(id: "SAR", nombre: "Riyal saudí", simbolo: "SAR", region: "Asia", tasaAEuro: 0.245),
        DivisaInfo(id: "QAR", nombre: "Riyal catarí", simbolo: "QAR", region: "Asia", tasaAEuro: 0.252),
        DivisaInfo(id: "ILS", nombre: "Nuevo séquel israelí", simbolo: "₪", region: "Asia", tasaAEuro: 0.25),
        DivisaInfo(id: "JOD", nombre: "Dinar jordano", simbolo: "JD", region: "Asia", tasaAEuro: 1.30),
        DivisaInfo(id: "KZT", nombre: "Tenge kazajo", simbolo: "₸", region: "Asia", tasaAEuro: 0.0019),
        DivisaInfo(id: "UZS", nombre: "Som uzbeko", simbolo: "so'm", region: "Asia", tasaAEuro: 0.000072),
        DivisaInfo(id: "NPR", nombre: "Rupia nepalesa", simbolo: "रू", region: "Asia", tasaAEuro: 0.0068),
        DivisaInfo(id: "LKR", nombre: "Rupia de Sri Lanka", simbolo: "Rs", region: "Asia", tasaAEuro: 0.0031),
        DivisaInfo(id: "KHR", nombre: "Riel camboyano", simbolo: "៛", region: "Asia", tasaAEuro: 0.00022),
        DivisaInfo(id: "LAK", nombre: "Kip laosiano", simbolo: "₭", region: "Asia", tasaAEuro: 0.000042)
    ]

    static func info(codigo: String) -> DivisaInfo {
        let up = codigo.uppercased()
        return todas.first(where: { $0.id == up }) ?? DivisaInfo(
            id: up.isEmpty ? "EUR" : up,
            nombre: up.isEmpty ? "Euro" : up,
            simbolo: up.isEmpty ? "€" : up,
            region: "Europa",
            tasaAEuro: 1.0
        )
    }

    static func aEuros(importeOriginal: Double, codigoDivisa: String, tasaPersonalizada: Double? = nil) -> Double {
        let up = codigoDivisa.uppercased()
        if up == "EUR" { return importeOriginal }
        if let custom = tasaPersonalizada, custom > 0 {
            return importeOriginal * custom
        }
        return importeOriginal * info(codigo: up).tasaAEuro
    }

    static func formatearOriginal(importe: Double, codigoDivisa: String) -> String {
        let div = info(codigo: codigoDivisa)
        if div.id == "JPY" || div.id == "KRW" || div.id == "VND" || div.id == "IDR" || div.id == "CLP" || div.id == "PYG" || div.id == "ISK" || div.id == "HUF" || div.id == "UZS" || div.id == "KHR" || div.id == "LAK" {
            return String(format: "%.0f %@", importe, div.id)
        }
        return String(format: "%.2f %@", importe, div.id)
    }
}

// ============================================================================
// CONSULTA EN TIEMPO REAL DE TIPO DE CAMBIO (INTERNET / GOOGLE SEARCH)
// ============================================================================

enum ConvertidorDivisasOnline {
    struct CotizacionEnVivo {
        let tasaAEuro: Double
        let fuente: String
        let enTiempoReal: Bool
    }

    static func obtenerTasaAEuro(codigoDivisa: String) async -> CotizacionEnVivo {
        let up = codigoDivisa.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let respaldo = CatalogoDivisas.info(codigo: up).tasaAEuro

        guard !up.isEmpty, up != "EUR" else {
            return CotizacionEnVivo(tasaAEuro: 1.0, fuente: "Euro (EUR)", enTiempoReal: true)
        }

        if let frankfurter = await consultarFrankfurter(divisa: up) {
            return CotizacionEnVivo(tasaAEuro: frankfurter, fuente: "Frankfurter / BCE en vivo", enTiempoReal: true)
        }

        if let openEr = await consultarOpenExchangeRates(divisa: up) {
            return CotizacionEnVivo(tasaAEuro: openEr, fuente: "Cambio de divisas en vivo", enTiempoReal: true)
        }

        if let googleResultado = await consultarCambioViaGoogle(divisa: up) {
            return CotizacionEnVivo(tasaAEuro: googleResultado, fuente: "Búsqueda Google en vivo", enTiempoReal: true)
        }

        return CotizacionEnVivo(tasaAEuro: respaldo, fuente: "Referencia local (sin red)", enTiempoReal: false)
    }

    private static func consultarFrankfurter(divisa: String) async -> Double? {
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(divisa)&to=EUR") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = json["rates"] as? [String: Any],
                  let tasa = rates["EUR"] as? Double, tasa > 0 else {
                return nil
            }
            return tasa
        } catch {
            return nil
        }
    }

    private static func consultarOpenExchangeRates(divisa: String) async -> Double? {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(divisa)") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = json["rates"] as? [String: Any],
                  let tasa = rates["EUR"] as? Double, tasa > 0 else {
                return nil
            }
            return tasa
        } catch {
            return nil
        }
    }

    private static func consultarCambioViaGoogle(divisa: String) async -> Double? {
        let consulta = "1 \(divisa) in EUR".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "1+\(divisa)+in+EUR"
        guard let url = URL(string: "https://www.google.com/search?q=\(consulta)&hl=es") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }

            let patrones = [
                #"data-value="([0-9]+(?:[.,][0-9]+)?)"#,
                #"([0-9]+(?:[.,][0-9]+)?)\s*(?:euro|euros|EUR)"#
            ]
            for patron in patrones {
                if let regex = try? NSRegularExpression(pattern: patron, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: html) {
                    let limpio = html[range].replacingOccurrences(of: ",", with: ".")
                    if let valor = Double(limpio), valor > 0 {
                        return valor
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}

// ============================================================================
// PREVISIÓN DEL TIEMPO EN DESTINO (Open-Meteo + Geocoding)
// ============================================================================

struct PrevisionDiaDestino: Identifiable {
    let id = UUID()
    let fechaTexto: String
    let tempMax: Double
    let tempMin: Double
    let codigoWMO: Int

    var iconoSF: String {
        switch codigoWMO {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    var descripcion: String {
        switch codigoWMO {
        case 0: return "Despejado"
        case 1, 2: return "Intervalos nubosos"
        case 3: return "Nublado"
        case 45, 48: return "Niebla"
        case 51, 53, 55, 61, 63, 80, 81: return "Lluvia"
        case 65, 82: return "Chubascos fuertes"
        case 71, 73, 75, 85, 86: return "Nieve"
        case 95, 96, 99: return "Tormenta"
        default: return "Variable"
        }
    }
}

enum ServicioClimaDestino {
    static func obtenerPrevision(destino: String, fechaInicio: Date, fechaFin: Date) async -> [PrevisionDiaDestino] {
        let limpio = destino.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return [] }

        let coordenada: CLLocationCoordinate2D?
        if let conocida = coordenadaRapida(limpio) {
            coordenada = conocida
        } else {
            let geocoder = CLGeocoder()
            let lugares = try? await geocoder.geocodeAddressString(limpio)
            coordenada = lugares?.first?.location?.coordinate
        }

        guard let coord = coordenada else { return [] }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let startStr = formatter.string(from: fechaInicio)
        let endStr = formatter.string(from: max(fechaInicio, fechaFin))

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&start_date=\(startStr)&end_date=\(endStr)"
        guard let url = URL(string: urlString) else { return [] }

        var req = URLRequest(url: url)
        req.timeoutInterval = 5.0

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let times = daily["time"] as? [String],
                  let codes = daily["weather_code"] as? [Int],
                  let maxTemps = daily["temperature_2m_max"] as? [Double],
                  let minTemps = daily["temperature_2m_min"] as? [Double] else {
                return []
            }

            let count = min(times.count, min(codes.count, min(maxTemps.count, minTemps.count)))
            var resultados: [PrevisionDiaDestino] = []

            let outFormatter = DateFormatter()
            outFormatter.locale = Locale(identifier: "es_ES")
            outFormatter.dateFormat = "EEE d"

            for idx in 0..<count {
                let etiqueta: String
                if let fechaDia = formatter.date(from: times[idx]) {
                    etiqueta = outFormatter.string(from: fechaDia).capitalized
                } else {
                    etiqueta = times[idx]
                }
                resultados.append(
                    PrevisionDiaDestino(
                        fechaTexto: etiqueta,
                        tempMax: maxTemps[idx],
                        tempMin: minTemps[idx],
                        codigoWMO: codes[idx]
                    )
                )
            }
            return resultados
        } catch {
            return []
        }
    }

    private static func coordenadaRapida(_ texto: String) -> CLLocationCoordinate2D? {
        let lower = texto.lowercased()
        let tabla: [(String, Double, Double)] = [
            ("praga", 50.0755, 14.4378),
            ("jerte", 40.2236, -5.7519),
            ("brihuega", 40.7606, -2.8692),
            ("madrid", 40.4168, -3.7038),
            ("barcelona", 41.3874, 2.1686),
            ("roma", 41.9028, 12.4964),
            ("paris", 48.8566, 2.3522),
            ("parís", 48.8566, 2.3522),
            ("londres", 51.5072, -0.1276),
            ("lisboa", 38.7223, -9.1393),
            ("oporto", 41.1579, -8.6291),
            ("sevilla", 37.3891, -5.9845),
            ("valencia", 39.4699, -0.3763)
        ]
        for (clave, lat, lon) in tabla where lower.contains(clave) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
}

// ============================================================================
// NOTIFICACIONES LOCALES EN iPHONE (Pop-up al cambiar notas rápidas e ideas)
// ============================================================================

enum NotificadorNotasIdeas {
    static func solicitarPermisoSiHaceFalta() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func notificarCambioNotasIdeas(tituloEscapada: String, totalNotas: Int) {
        solicitarPermisoSiHaceFalta()

        let contenido = UNMutableNotificationContent()
        contenido.title = "Notas e ideas actualizadas"
        contenido.body = "Hubo un cambio en las notas rápidas e ideas de «\(tituloEscapada)» (\(totalNotas) \(totalNotas == 1 ? "nota" : "notas"))."
        contenido.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let idSolicitud = "notas_ideas_\(UUID().uuidString)"
        let peticion = UNNotificationRequest(identifier: idSolicitud, content: contenido, trigger: trigger)

        UNUserNotificationCenter.current().add(peticion) { _ in }
    }
}

// ============================================================================
// 3. GESTOR DE ESTADO Y SINCRONIZACIÓN EN TIEMPO REAL CON FIRESTORE
// ============================================================================

@MainActor
class EscapadasStore: ObservableObject {
    @Published var escapadas: [Escapada] = []
    @Published var wishlist: [DestinoWishlist] = []
    @Published var codigoPareja: String {
        didSet {
            UserDefaults.standard.set(codigoPareja, forKey: "codigo_pareja_ios")
        }
    }
    @Published var estadoNube: String = "Conectando..."
    @Published var firebaseActivo: Bool = false

    private var db: Firestore?
    private var listener: ListenerRegistration?
    private var wishlistListener: ListenerRegistration?
    private let localBackupKey = "nuestras_escapadas_backup_v2"
    private let wishlistBackupKey = "nuestras_escapadas_wishlist_v1"
    private let deviceIdKey = "nuestras_escapadas_device_id_v1"
    private var primeraCargaSala = true
    private var ideasPorEscapada: [UUID: [String]] = [:]
    private let deviceId: String

    init() {
        if let savedId = UserDefaults.standard.string(forKey: deviceIdKey), !savedId.isEmpty {
            self.deviceId = savedId
        } else {
            let nuevoId = UUID().uuidString
            UserDefaults.standard.set(nuevoId, forKey: deviceIdKey)
            self.deviceId = nuevoId
        }
        let guardado = UserDefaults.standard.string(forKey: "codigo_pareja_ios") ?? "VIAJE-2026"
        self.codigoPareja = guardado
        cargarCopiaLocal()
        NotificadorNotasIdeas.solicitarPermisoSiHaceFalta()
        configurarFirebase()
    }

    deinit {
        listener?.remove()
        wishlistListener?.remove()
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
        wishlistListener?.remove()
        primeraCargaSala = true
        estadoNube = "Conectando..."

        let coleccion = db.collection("parejas").document(limpio).collection("escapadas")
        let coleccionWishlist = db.collection("parejas").document(limpio).collection("wishlist")

        wishlistListener = coleccionWishlist.addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor [weak self] in
                guard let self = self, let documents = snapshot?.documents else { return }
                let items: [DestinoWishlist] = documents.compactMap { doc in
                    try? doc.data(as: DestinoWishlist.self)
                }
                self.wishlist = items.sorted {
                    if $0.prioridadAlta != $1.prioridadAlta {
                        return $0.prioridadAlta && !$1.prioridadAlta
                    }
                    return $0.fechaAgregado > $1.fechaAgregado
                }
                self.guardarWishlistLocal()
            }
        }

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

                if !self.primeraCargaSala, let docChanges = snapshot?.documentChanges {
                    for change in docChanges where change.type == .modified {
                        let data = change.document.data()
                        let autorCambio = data["lastModifiedByDeviceId"] as? String
                        if autorCambio != self.deviceId,
                           let decodificada = try? change.document.data(as: Escapada.self) {
                            let ideasAnteriores = self.ideasPorEscapada[decodificada.id] ?? []
                            if ideasAnteriores != decodificada.ideas {
                                NotificadorNotasIdeas.notificarCambioNotasIdeas(
                                    tituloEscapada: decodificada.titulo,
                                    totalNotas: decodificada.ideas.count
                                )
                            }
                        }
                    }
                }

                self.primeraCargaSala = false
                self.escapadas = remotas
                self.registrarSnapshotIdeas(remotas)
                self.guardarCopiaLocal()
            }
        }
    }

    private func registrarSnapshotIdeas(_ lista: [Escapada]) {
        var mapa: [UUID: [String]] = [:]
        for esc in lista {
            mapa[esc.id] = esc.ideas
        }
        ideasPorEscapada = mapa
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
        registrarSnapshotIdeas(escapadas)
        guardarCopiaLocal()
        guardarEnFirestore(nueva)
    }

    func actualizarEscapada(_ editada: Escapada) {
        if let idx = escapadas.firstIndex(where: { $0.id == editada.id }) {
            escapadas[idx] = editada
        } else {
            escapadas.append(editada)
        }
        registrarSnapshotIdeas(escapadas)
        guardarCopiaLocal()
        guardarEnFirestore(editada)
    }

    func eliminarEscapada(_ escapada: Escapada) {
        escapadas.removeAll { $0.id == escapada.id }
        registrarSnapshotIdeas(escapadas)
        guardarCopiaLocal()
        eliminarDeFirestore(escapada)
    }

    func agregarDestinoWishlist(_ destino: DestinoWishlist) {
        wishlist.insert(destino, at: 0)
        wishlist.sort {
            if $0.prioridadAlta != $1.prioridadAlta {
                return $0.prioridadAlta && !$1.prioridadAlta
            }
            return $0.fechaAgregado > $1.fechaAgregado
        }
        guardarWishlistLocal()
        guardarWishlistEnFirestore(destino)
    }

    func alternarPrioridadWishlist(_ destino: DestinoWishlist) {
        guard let idx = wishlist.firstIndex(where: { $0.id == destino.id }) else { return }
        wishlist[idx].prioridadAlta.toggle()
        let actualizado = wishlist[idx]
        wishlist.sort {
            if $0.prioridadAlta != $1.prioridadAlta {
                return $0.prioridadAlta && !$1.prioridadAlta
            }
            return $0.fechaAgregado > $1.fechaAgregado
        }
        guardarWishlistLocal()
        guardarWishlistEnFirestore(actualizado)
    }

    func eliminarDestinoWishlist(_ destino: DestinoWishlist) {
        wishlist.removeAll { $0.id == destino.id }
        guardarWishlistLocal()
        eliminarWishlistDeFirestore(destino)
    }

    private func guardarEnFirestore(_ escapada: Escapada) {
        guard let db = db else { return }
        do {
            let docRef = db.collection("parejas")
                .document(codigoPareja)
                .collection("escapadas")
                .document(escapada.id.uuidString)
            try docRef.setData(from: escapada, merge: false)
            docRef.setData(["lastModifiedByDeviceId": deviceId], merge: true)
            estadoNube = "En vivo"
        } catch {
            estadoNube = "Error al guardar"
        }
    }

    private func eliminarDeFirestore(_ escapada: Escapada) {
        guard let db = db else { return }
        db.collection("parejas")
            .document(codigoPareja)
            .collection("escapadas")
            .document(escapada.id.uuidString)
            .delete { [weak self] error in
                Task { @MainActor [weak self] in
                    if error != nil {
                        self?.estadoNube = "Error al borrar"
                    }
                }
            }
    }

    private func guardarWishlistEnFirestore(_ destino: DestinoWishlist) {
        guard let db = db else { return }
        do {
            try db.collection("parejas")
                .document(codigoPareja)
                .collection("wishlist")
                .document(destino.id.uuidString)
                .setData(from: destino, merge: false)
        } catch {
            estadoNube = "Error al guardar wishlist"
        }
    }

    private func eliminarWishlistDeFirestore(_ destino: DestinoWishlist) {
        guard let db = db else { return }
        db.collection("parejas")
            .document(codigoPareja)
            .collection("wishlist")
            .document(destino.id.uuidString)
            .delete { _ in }
    }

    private func guardarWishlistLocal() {
        do {
            let data = try JSONEncoder().encode(wishlist)
            UserDefaults.standard.set(data, forKey: wishlistBackupKey)
        } catch {
            // Ignorar error de respaldo local
        }
    }

    private func guardarCopiaLocal() {
        do {
            let data = try JSONEncoder().encode(escapadas)
            UserDefaults.standard.set(data, forKey: localBackupKey)
        } catch {
            // Ignorar error de respaldo local
        }
    }

    private func cargarCopiaLocal() {
        if let wishData = UserDefaults.standard.data(forKey: wishlistBackupKey),
           let decWish = try? JSONDecoder().decode([DestinoWishlist].self, from: wishData) {
            wishlist = decWish
        }
        guard let data = UserDefaults.standard.data(forKey: localBackupKey) else { return }
        do {
            escapadas = try JSONDecoder().decode([Escapada].self, from: data)
            registrarSnapshotIdeas(escapadas)
        } catch {
            escapadas = []
        }
    }

    private func cargarEjemplosIniciales(subirANube: Bool) {
        let calendario = Calendar.current
        let hoy = Date()
        let inicio1 = calendario.date(byAdding: .day, value: 14, to: hoy) ?? hoy
        let fin1 = calendario.date(byAdding: .day, value: 17, to: hoy) ?? hoy
        let inicio2 = calendario.date(byAdding: .day, value: 35, to: hoy) ?? hoy
        let fin2 = calendario.date(byAdding: .day, value: 37, to: hoy) ?? hoy

        let ejemplos: [Escapada] = [
            Escapada(
                titulo: "Escapada de invierno",
                destino: "Praga y montañas",
                fechaInicio: inicio1,
                fechaFin: fin1,
                icono: "✈️",
                tieneVuelos: true,
                tieneTrenes: false,
                esSorpresa: false,
                pistaSorpresa: "",
                diasRevelarSorpresaAntes: 0,
                recuerdo: "",
                vuelos: [
                    Vuelo(
                        trayecto: "Ida",
                        origen: "MAD",
                        destino: "PRG",
                        fechaHoraSalida: calendario.date(bySettingHour: 8, minute: 30, second: 0, of: inicio1) ?? inicio1,
                        fechaHoraLlegada: calendario.date(bySettingHour: 11, minute: 25, second: 0, of: inicio1) ?? inicio1,
                        aerolinea: "Iberia",
                        numeroVuelo: "IB3140",
                        localizador: "K8M9LP",
                        terminalPuerta: "Terminal 4",
                        urlReserva: "https://www.iberia.com/es/gestion-reservas/"
                    )
                ],
                checklist: [
                    ItemChecklist(texto: "DNI / Pasaportes en vigor", completado: true, asignadoA: "Ambos"),
                    ItemChecklist(texto: "Ropa térmica y guantes", completado: false, asignadoA: "Ambos")
                ],
                retosFotograficos: [
                    RetoFotografico(titulo: "Un café con vistas"),
                    RetoFotografico(titulo: "El plato más curioso del viaje")
                ],
                itinerario: [
                    ActividadDia(diaIndex: 1, nombreSitio: "Puente de Carlos", urlSitio: "https://www.prague.eu")
                ],
                ideas: ["Paseo por el casco antiguo"]
            ),
            Escapada(
                titulo: "Fin de semana secreto",
                destino: "Cabaña en el Valle del Jerte",
                fechaInicio: inicio2,
                fechaFin: fin2,
                icono: "🎁",
                tieneVuelos: false,
                tieneTrenes: true,
                esSorpresa: true,
                pistaSorpresa: "Abrigo cómodo y ganas de desconectar",
                diasRevelarSorpresaAntes: 3,
                recuerdo: "",
                vuelos: [],
                checklist: [
                    ItemChecklist(texto: "Calzado cómodo", completado: false, asignadoA: "Ambos")
                ],
                retosFotograficos: [
                    RetoFotografico(titulo: "Atardecer juntos")
                ],
                ideas: []
            )
        ]

        escapadas = ejemplos
        registrarSnapshotIdeas(ejemplos)
        guardarCopiaLocal()
        if subirANube {
            for esc in ejemplos {
                guardarEnFirestore(esc)
            }
        }
    }
}

// ============================================================================
// 4. PUNTO DE ENTRADA DE LA APP iOS
// ============================================================================

@main
struct NuestrasEscapadasApp: App {
    @StateObject private var store = EscapadasStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
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
                MapaDestinosView()
                    .navigationTitle("Nuestro Mapa")
            }
            .tabItem {
                Label("Mapa", systemImage: "map.fill")
            }

            NavigationStack {
                WishlistDestinosView()
                    .navigationTitle("Wishlist")
            }
            .tabItem {
                Label("Wishlist", systemImage: "sparkles")
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
                } else {
                    HStack(spacing: 6) {
                        if !escapada.vuelos.isEmpty {
                            Label("\(escapada.vuelos.count)", systemImage: "airplane")
                                .font(.caption.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        if !escapada.trenes.isEmpty {
                            Label("\(escapada.trenes.count)", systemImage: "tram.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                    }
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
    @State private var nuevoRetoTexto = ""
    @State private var nuevaIdeaTexto = ""
    @State private var mostrandoAgregarVuelo = false
    @State private var mostrandoAgregarTren = false
    @State private var mostrandoEditarAlojamiento = false
    @State private var alojamientoAEditar: AlojamientoInfo? = nil
    @State private var mostrandoAgregarGasto = false
    @State private var idAlojamientoCopiado: UUID? = nil

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

                    Section {
                        Button {
                            mostrandoAgregarGasto = true
                        } label: {
                            Label("Añadir gasto", systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                        }

                        if escapada.gastos.isEmpty {
                            Text("Aún no hay gastos registrados en esta escapada.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(escapada.gastos) { gasto in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(gasto.concepto)
                                            .font(.subheadline.weight(.medium))
                                        Text("\(gasto.categoria) · Pagó: \(gasto.pagadoPor)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if gasto.monedaEfectiva != "EUR" {
                                            Text("Pagado: \(CatalogoDivisas.formatearOriginal(importe: gasto.importeOriginalEfectivo, codigoDivisa: gasto.monedaEfectiva))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(String(format: "%.2f €", gasto.importe))
                                        .font(.subheadline.bold().monospacedDigit())
                                }
                            }
                            .onDelete { offsets in
                                var copia = escapada
                                copia.gastos.remove(atOffsets: offsets)
                                store.actualizarEscapada(copia)
                            }

                            let totalEuros = escapada.gastos.reduce(0) { $0 + $1.importe }
                            HStack {
                                Text("Total en euros")
                                    .font(.caption.bold())
                                Spacer()
                                Text(String(format: "%.2f €", totalEuros))
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    } header: {
                        Text("Gastos compartidos")
                    }

                    Section {
                        HStack {
                            TextField("Nuevo reto fotográfico...", text: $nuevoRetoTexto)
                            Button {
                                let limpio = nuevoRetoTexto.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !limpio.isEmpty else { return }
                                var copia = escapada
                                copia.retosFotograficos.append(RetoFotografico(titulo: limpio))
                                store.actualizarEscapada(copia)
                                nuevoRetoTexto = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(nuevoRetoTexto.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        if escapada.retosFotograficos.isEmpty {
                            Text("Añade retos de fotos para hacer juntos durante el viaje.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(escapada.retosFotograficos) { reto in
                                RetoFotograficoFilaView(
                                    reto: reto,
                                    onGuardarFotoBase64: { base64 in
                                        var copia = escapada
                                        if let idx = copia.retosFotograficos.firstIndex(where: { $0.id == reto.id }) {
                                            copia.retosFotograficos[idx].fotoBase64 = base64
                                            copia.retosFotograficos[idx].completado = base64 != nil
                                            store.actualizarEscapada(copia)
                                        }
                                    },
                                    onQuitarFoto: {
                                        var copia = escapada
                                        if let idx = copia.retosFotograficos.firstIndex(where: { $0.id == reto.id }) {
                                            copia.retosFotograficos[idx].fotoBase64 = nil
                                            copia.retosFotograficos[idx].completado = false
                                            store.actualizarEscapada(copia)
                                        }
                                    }
                                )
                            }
                            .onDelete { offsets in
                                var copia = escapada
                                copia.retosFotograficos.remove(atOffsets: offsets)
                                store.actualizarEscapada(copia)
                            }
                        }
                    } header: {
                        Text("Retos fotográficos de la escapada")
                    }

                    Section {
                        FilaEstrellasView(
                            titulo: "General",
                            puntuacion: Binding(
                                get: { escapada.valoracion.general },
                                set: { val in
                                    var copia = escapada
                                    copia.valoracion.general = val
                                    store.actualizarEscapada(copia)
                                }
                            )
                        )
                        FilaEstrellasView(
                            titulo: "Alojamiento",
                            puntuacion: Binding(
                                get: { escapada.valoracion.alojamiento },
                                set: { val in
                                    var copia = escapada
                                    copia.valoracion.alojamiento = val
                                    store.actualizarEscapada(copia)
                                }
                            )
                        )
                        FilaEstrellasView(
                            titulo: "Comida",
                            puntuacion: Binding(
                                get: { escapada.valoracion.comida },
                                set: { val in
                                    var copia = escapada
                                    copia.valoracion.comida = val
                                    store.actualizarEscapada(copia)
                                }
                            )
                        )
                        FilaEstrellasView(
                            titulo: "Planes",
                            puntuacion: Binding(
                                get: { escapada.valoracion.planes },
                                set: { val in
                                    var copia = escapada
                                    copia.valoracion.planes = val
                                    store.actualizarEscapada(copia)
                                }
                            )
                        )
                    } header: {
                        Text("Valoración del viaje")
                    }
                }

                // Checklist compartida
                Section("Checklist compartida") {
                    HStack {
                        TextField("Añadir cosa...", text: $nuevoItemTexto)
                        Picker("Asignado", selection: $nuevoItemAsignado) {
                            Text("Ambos").tag("Ambos")
                            Text("Yo").tag("Yo")
                            Text("Tú").tag("Tú")
                        }
                        .labelsHidden()
                        Button {
                            guard !nuevoItemTexto.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            var copia = escapada
                            copia.checklist.append(ItemChecklist(texto: nuevoItemTexto.trimmingCharacters(in: .whitespaces), asignadoA: nuevoItemAsignado))
                            store.actualizarEscapada(copia)
                            nuevoItemTexto = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(nuevoItemTexto.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    ForEach(escapada.checklist) { item in
                        Button {
                            var copia = escapada
                            if let idx = copia.checklist.firstIndex(where: { $0.id == item.id }) {
                                copia.checklist[idx].completado.toggle()
                                store.actualizarEscapada(copia)
                            }
                        } label: {
                            HStack {
                                Image(systemName: item.completado ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.completado ? Color.accentColor : Color.secondary)
                                Text(item.texto)
                                    .strikethrough(item.completado)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(item.asignadoA)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        var copia = escapada
                        copia.checklist.remove(atOffsets: offsets)
                        store.actualizarEscapada(copia)
                    }
                }

                // Notas rápidas e ideas
                Section("Notas rápidas e ideas") {
                    HStack {
                        TextField("Idea o enlace...", text: $nuevaIdeaTexto)
                        Button {
                            guard !nuevaIdeaTexto.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            var copia = escapada
                            copia.ideas.append(nuevaIdeaTexto.trimmingCharacters(in: .whitespaces))
                            store.actualizarEscapada(copia)
                            nuevaIdeaTexto = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(nuevaIdeaTexto.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    ForEach(escapada.ideas, id: \.self) { idea in
                        if let url = URL(string: idea), idea.lowercased().hasPrefix("http") {
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
                }

                // Recuerdo del viaje
                Section("Nuestro recuerdo") {
                    TextField("Escribe aquí lo mejor del viaje...", text: Binding(
                        get: { escapada.recuerdo },
                        set: { nuevoRecuerdo in
                            var copia = escapada
                            copia.recuerdo = nuevoRecuerdo
                            store.actualizarEscapada(copia)
                        }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                // Borrar escapada
                Section {
                    Button(role: .destructive) {
                        store.eliminarEscapada(escapada)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Eliminar escapada")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(escapada.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                diaSeleccionado = min(max(1, diaSeleccionado), escapada.totalDias)
            }
            .sheet(isPresented: $mostrandoAgregarVuelo) {
                AgregarVueloSheet(escapada: escapada)
            }
            .sheet(isPresented: $mostrandoAgregarTren) {
                AgregarTrenSheet(escapada: escapada)
            }
            .sheet(isPresented: $mostrandoEditarAlojamiento) {
                EditarAlojamientoSheet(escapada: escapada, alojamientoExistente: alojamientoAEditar)
            }
            .sheet(isPresented: $mostrandoAgregarGasto) {
                AgregarGastoSheet(escapada: escapada)
            }
        } else {
            ContentUnavailableView("Escapada no encontrada", systemImage: "exclamationmark.triangle")
        }
    }
}

struct PrevisionTiempoDestinoSection: View {
    let destino: String
    let fechaInicio: Date
    let fechaFin: Date

    @State private var diasPrevision: [PrevisionDiaDestino] = []
    @State private var cargando = false

    var body: some View {
        Section {
            if cargando {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Consultando previsión del tiempo para \(destino)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if diasPrevision.isEmpty {
                Text("Previsión no disponible para estas fechas o ubicación todavía.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(diasPrevision) { dia in
                            VStack(spacing: 6) {
                                Text(dia.fechaTexto)
                                    .font(.caption.bold())
                                Image(systemName: dia.iconoSF)
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                                Text(dia.descripcion)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(String(format: "%.0f°", dia.tempMax))
                                        .font(.caption.bold().monospacedDigit())
                                    Text(String(format: "%.0f°", dia.tempMin))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 92)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Previsión del tiempo en \(destino)")
        }
        .task(id: "\(destino)|\(fechaInicio.timeIntervalSince1970)|\(fechaFin.timeIntervalSince1970)") {
            cargando = true
            diasPrevision = await ServicioClimaDestino.obtenerPrevision(
                destino: destino,
                fechaInicio: fechaInicio,
                fechaFin: fechaFin
            )
            cargando = false
        }
    }
}

struct RetoFotograficoFilaView: View {
    let reto: RetoFotografico
    let onGuardarFotoBase64: (String?) -> Void
    let onQuitarFoto: () -> Void

    @State private var itemSeleccionado: PhotosPickerItem? = nil

    private var imagenGuardada: UIImage? {
        guard let str = reto.fotoBase64,
              let data = Data(base64Encoded: str) else { return nil }
        return UIImage(data: data)
    }

    private var estaCompletado: Bool {
        reto.completado || imagenGuardada != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: estaCompletado ? "checkmark.circle.fill" : "camera.circle")
                    .font(.title3)
                    .foregroundStyle(estaCompletado ? Color.green : Color.accentColor)

                Text(reto.titulo)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(estaCompletado)
                    .foregroundStyle(estaCompletado ? .secondary : .primary)

                Spacer()

                PhotosPicker(selection: $itemSeleccionado, matching: .images) {
                    Label(imagenGuardada == nil ? "Añadir foto" : "Cambiar foto", systemImage: "photo.badge.plus")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
            }

            if let img = imagenGuardada {
                HStack(alignment: .bottom, spacing: 10) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Spacer()

                    Button(role: .destructive) {
                        itemSeleccionado = nil
                        onQuitarFoto()
                    } label: {
                        Label("Quitar foto", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: itemSeleccionado) { _, nuevoItem in
            guard let nuevoItem else { return }
            Task {
                if let datos = try? await nuevoItem.loadTransferable(type: Data.self),
                   let uiImg = UIImage(data: datos),
                   let comprimida = uiImg.jpegData(compressionQuality: 0.65) {
                    let base64 = comprimida.base64EncodedString()
                    await MainActor.run {
                        onGuardarFotoBase64(base64)
                    }
                }
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

struct TrenCardView: View {
    let tren: BilleteTren
    @State private var copiado = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(tren.trayecto.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())

                Text("\(tren.operador)\(tren.numeroTren.isEmpty ? "" : " · \(tren.numeroTren)")")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading) {
                    Text(tren.estacionOrigen)
                        .font(.subheadline.bold())
                    Text(tren.fechaHoraSalida.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Image(systemName: "tram.fill")
                    .foregroundStyle(Color.accentColor)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(tren.estacionDestino)
                        .font(.subheadline.bold())
                    Text(tren.fechaHoraLlegada.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                }
            }

            if !tren.cocheAsiento.isEmpty {
                HStack {
                    Text("Plaza: \(tren.cocheAsiento)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            HStack {
                if !tren.localizador.isEmpty {
                    Button {
                        UIPasteboard.general.string = tren.localizador
                        copiado = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiado = false }
                    } label: {
                        HStack {
                            Text("Loc: \(tren.localizador)")
                                .font(.caption.monospaced().bold())
                            Image(systemName: copiado ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                let destinoUrl = tren.urlReserva.isEmpty ? TrenesEspana.urlParaOperador(tren.operador) : tren.urlReserva
                if let url = URL(string: destinoUrl) {
                    Link(destination: url) {
                        Label("Web \(tren.operador)", systemImage: "safari")
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
// 8. FORMULARIOS MODALES (Nueva Escapada, Vuelos, Trenes, Alojamientos, Gastos, Wishlist, Sync)
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

    // Opción independiente 1: Vuelos
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

    // Opción independiente 2: Trenes españoles
    @State private var tieneTrenes = false
    @State private var operadorTren = "Renfe"

    let iconos = ["✈️", "🚆", "🏔️", "🏖️", "🌿", "🍷", "🚗", "🎁", "🏙️"]

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
                    Toggle("✈️ ¿Hay vuelo?", isOn: $tieneVuelos)

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

                    Toggle("🚆 ¿Hay trenes?", isOn: $tieneTrenes)

                    if tieneTrenes {
                        Picker("Operador habitual", selection: $operadorTren) {
                            ForEach(TrenesEspana.operadores) { op in
                                Text(op.nombre).tag(op.nombre)
                            }
                        }

                        ForEach(TrenesEspana.operadores) { op in
                            if let url = URL(string: op.urlWeb) {
                                Link(destination: url) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(op.nombre)
                                                .font(.subheadline.bold())
                                            Text(op.descripcion)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Transporte (vuelos y/o trenes)")
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
                            tieneTrenes: tieneTrenes,
                            esSorpresa: esSorpresa,
                            pistaSorpresa: pista,
                            diasRevelarSorpresaAntes: max(0, diasRevelarAntes),
                            recuerdo: "",
                            vuelos: vuelosIniciales,
                            trenes: [],
                            checklist: [ItemChecklist(texto: "Revisar documentación", completado: false, asignadoA: "Ambos")],
                            retosFotograficos: [RetoFotografico(titulo: "Un café con vistas")],
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

struct AgregarTrenSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada

    @State private var operador = "Renfe"
    @State private var trayecto = "Ida"
    @State private var estacionOrigen = ""
    @State private var estacionDestino = ""
    @State private var salida = Date()
    @State private var llegada = Date()
    @State private var numeroTren = ""
    @State private var localizador = ""
    @State private var cocheAsiento = ""
    @State private var urlReserva = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Operador español y páginas oficiales") {
                    Picker("Operador", selection: $operador) {
                        ForEach(TrenesEspana.operadores) { op in
                            Text(op.nombre).tag(op.nombre)
                        }
                    }
                    .onChange(of: operador) { _, nuevoOp in
                        urlReserva = TrenesEspana.urlParaOperador(nuevoOp)
                    }

                    ForEach(TrenesEspana.operadores) { op in
                        if let url = URL(string: op.urlWeb) {
                            Link(destination: url) {
                                Label("Abrir \(op.nombre)", systemImage: "safari")
                                    .font(.caption.bold())
                            }
                        }
                    }
                }

                Section("Trayecto y estaciones") {
                    Picker("Trayecto", selection: $trayecto) {
                        Text("Ida").tag("Ida")
                        Text("Vuelta").tag("Vuelta")
                    }
                    TextField("Estación origen (ej: Madrid Atocha)", text: $estacionOrigen)
                    TextField("Estación destino (ej: Valencia Joaquín Sorolla)", text: $estacionDestino)
                    DatePicker("Salida", selection: $salida)
                    DatePicker("Llegada", selection: $llegada)
                }

                Section("Billete y plaza") {
                    TextField("Nº de tren (opcional)", text: $numeroTren)
                    TextField("Localizador (opcional)", text: $localizador)
                        .autocapitalization(.allCharacters)
                    TextField("Coche y asiento (ej: Coche 4 · Asiento 12A)", text: $cocheAsiento)
                    TextField("URL de reserva", text: $urlReserva)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Añadir billete de tren")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                salida = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: escapada.fechaInicio) ?? escapada.fechaInicio
                llegada = Calendar.current.date(byAdding: .minute, value: 140, to: salida) ?? salida
                urlReserva = TrenesEspana.urlParaOperador(operador)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let nuevoTren = BilleteTren(
                            operador: operador,
                            trayecto: trayecto,
                            estacionOrigen: estacionOrigen.trimmingCharacters(in: .whitespacesAndNewlines),
                            estacionDestino: estacionDestino.trimmingCharacters(in: .whitespacesAndNewlines),
                            fechaHoraSalida: salida,
                            fechaHoraLlegada: llegada,
                            numeroTren: numeroTren.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            localizador: localizador.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            cocheAsiento: cocheAsiento.trimmingCharacters(in: .whitespacesAndNewlines),
                            urlReserva: urlReserva.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        var copia = escapada
                        copia.tieneTrenes = true
                        copia.trenes.append(nuevoTren)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(estacionOrigen.trimmingCharacters(in: .whitespaces).isEmpty || estacionDestino.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
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
                    let totalGastado = esc.gastos.reduce(0) { $0 + $1.importe }
                    let mediaEstrellas = esc.valoracion.mediaEstrellas
                    NavigationLink(value: esc) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(esc.icono) \(esc.titulo)")
                                    .font(.headline)
                                Spacer()
                                if let media = mediaEstrellas {
                                    HStack(spacing: 3) {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.orange)
                                        Text(String(format: "%.1f", media))
                                            .font(.caption.bold().monospacedDigit())
                                            .foregroundStyle(Color.orange)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.14))
                                    .clipShape(Capsule())
                                }
                                Text(esc.fechaInicio.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("📍 \(esc.destino)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Gastado: \(String(format: "%.2f €", totalGastado))")
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
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

struct EditarAlojamientoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    let alojamientoExistente: AlojamientoInfo?

    @State private var alojamientoId = UUID()
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
                    TextField("Hora Check-in (ej: 15:00)", text: $horaCheckIn)
                    TextField("Hora Check-out (ej: 11:00)", text: $horaCheckOut)
                    TextField("Código / Localizador de reserva", text: $codigoReserva)
                        .autocapitalization(.allCharacters)
                    TextField("Enlace de la reserva (Booking, Airbnb...)", text: $urlReserva)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle(alojamientoExistente == nil ? "Nuevo alojamiento" : "Editar alojamiento")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let existente = alojamientoExistente {
                    alojamientoId = existente.id
                    nombre = existente.nombre
                    direccion = existente.direccion
                    horaCheckIn = existente.horaCheckIn
                    horaCheckOut = existente.horaCheckOut
                    codigoReserva = existente.codigoReserva
                    urlReserva = existente.urlReserva
                } else {
                    alojamientoId = UUID()
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
                        let editado = AlojamientoInfo(
                            id: alojamientoId,
                            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                            direccion: direccion.trimmingCharacters(in: .whitespacesAndNewlines),
                            horaCheckIn: horaCheckIn.trimmingCharacters(in: .whitespacesAndNewlines),
                            horaCheckOut: horaCheckOut.trimmingCharacters(in: .whitespacesAndNewlines),
                            codigoReserva: codigoReserva.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            urlReserva: urlLimpia
                        )

                        var listaActual = escapada.todosLosAlojamientos
                        if let idx = listaActual.firstIndex(where: { $0.id == editado.id }) {
                            listaActual[idx] = editado
                        } else if editado.tieneDatos {
                            listaActual.append(editado)
                        }

                        var copia = escapada
                        copia.alojamiento = listaActual.first ?? AlojamientoInfo()
                        copia.alojamientos = Array(listaActual.dropFirst())
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AgregarGastoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada

    @State private var concepto = ""
    @State private var importeTexto = ""
    @State private var codigoDivisa = "EUR"
    @State private var tasaManualTexto = ""
    @State private var pagadoPor = "Yo"
    @State private var categoria = "Comida"
    @State private var consultandoCambio = false
    @State private var estadoCambioTexto = ""

    let categorias = ["Comida", "Transporte", "Alojamiento", "Entradas", "Otros"]
    let regiones = ["Europa", "América", "Asia"]

    private var valorImporte: Double {
        let limpio = importeTexto.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(limpio) ?? 0
    }

    private var tasaEfectivaAEuro: Double {
        let limpioTasa = tasaManualTexto.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if let custom = Double(limpioTasa), custom > 0 {
            return custom
        }
        return CatalogoDivisas.info(codigo: codigoDivisa).tasaAEuro
    }

    private var equivalenteEnEuros: Double {
        CatalogoDivisas.aEuros(
            importeOriginal: valorImporte,
            codigoDivisa: codigoDivisa,
            tasaPersonalizada: tasaEfectivaAEuro
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle del gasto") {
                    TextField("Concepto (ej: Cena en el centro)", text: $concepto)
                    TextField("Importe en la moneda pagada (ej: 450)", text: $importeTexto)
                        .keyboardType(.decimalPad)
                }

                Section("Divisa de pago y conversión a euros") {
                    Picker("Moneda pagada", selection: $codigoDivisa) {
                        ForEach(regiones, id: \.self) { region in
                            Section(region) {
                                ForEach(CatalogoDivisas.todas.filter { $0.region == region }) { div in
                                    Text("\(div.id) · \(div.nombre)").tag(div.id)
                                }
                            }
                        }
                    }
                    .onChange(of: codigoDivisa) { _, nuevaDivisa in
                        Task {
                            await validarCambioEnTiempoReal(divisa: nuevaDivisa)
                        }
                    }

                    HStack {
                        Button {
                            Task {
                                await validarCambioEnTiempoReal(divisa: codigoDivisa)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if consultandoCambio {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(consultandoCambio ? "Consultando cambio en Google..." : "Validar cambio en tiempo real")
                                    .font(.caption.bold())
                            }
                        }
                        .disabled(consultandoCambio || codigoDivisa == "EUR")

                        Spacer()
                    }

                    if !estadoCambioTexto.isEmpty {
                        Text(estadoCambioTexto)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if codigoDivisa != "EUR" {
                        HStack {
                            Text("1 \(codigoDivisa) en €")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("Tasa €", text: $tasaManualTexto)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 110)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Importe pagado:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CatalogoDivisas.formatearOriginal(importe: valorImporte, codigoDivisa: codigoDivisa))
                                .font(.subheadline.bold().monospacedDigit())
                        }
                        HStack {
                            Text("Equivalente en euros:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", equivalenteEnEuros))
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Section("Reparto y categoría") {
                    Picker("¿Quién pagó?", selection: $pagadoPor) {
                        Text("Yo").tag("Yo")
                        Text("Tú").tag("Tú")
                    }
                    .pickerStyle(.segmented)

                    Picker("Categoría", selection: $categoria) {
                        ForEach(categorias, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Nuevo gasto")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                tasaManualTexto = String(format: "%.6f", CatalogoDivisas.info(codigo: codigoDivisa).tasaAEuro)
                Task {
                    await validarCambioEnTiempoReal(divisa: codigoDivisa)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        guard valorImporte > 0 else { return }
                        let nuevoGasto = GastoViaje(
                            concepto: concepto.trimmingCharacters(in: .whitespacesAndNewlines),
                            importe: equivalenteEnEuros,
                            importeOriginal: valorImporte,
                            monedaCodigo: codigoDivisa,
                            tasaCambioAEuro: tasaEfectivaAEuro,
                            pagadoPor: pagadoPor,
                            categoria: categoria
                        )
                        var copia = escapada
                        copia.gastos.append(nuevoGasto)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(concepto.trimmingCharacters(in: .whitespaces).isEmpty || valorImporte <= 0)
                }
            }
        }
    }

    private func validarCambioEnTiempoReal(divisa: String) async {
        let up = divisa.uppercased()
        if up == "EUR" {
            tasaManualTexto = "1.000000"
            estadoCambioTexto = "✓ Moneda base Euro (1 EUR = 1,00 €)"
            return
        }

        consultandoCambio = true
        let cotizacion = await ConvertidorDivisasOnline.obtenerTasaAEuro(codigoDivisa: up)
        consultandoCambio = false

        tasaManualTexto = String(format: "%.6f", cotizacion.tasaAEuro)
        if cotizacion.enTiempoReal {
            estadoCambioTexto = "✓ \(cotizacion.fuente): 1 \(up) = \(String(format: "%.4f €", cotizacion.tasaAEuro))"
        } else {
            estadoCambioTexto = "⚠️ \(cotizacion.fuente): 1 \(up) ≈ \(String(format: "%.4f €", cotizacion.tasaAEuro))"
        }
    }
}

struct PinDestinoMapa: Identifiable {
    let id: UUID
    let titulo: String
    let destino: String
    let icono: String
    let yaVivida: Bool
    let coordenada: CLLocationCoordinate2D
}

struct MapaDestinosView: View {
    @EnvironmentObject var store: EscapadasStore
    @State private var pines: [PinDestinoMapa] = []
    @State private var posicionCamara: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.5, longitude: 6.0),
            span: MKCoordinateSpan(latitudeDelta: 28, longitudeDelta: 28)
        )
    )

    private var escapadasVisibles: [Escapada] {
        store.escapadas.filter { !($0.esSorpresa && !$0.sorpresaDesbloqueada) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $posicionCamara) {
                ForEach(pines) { pin in
                    Annotation(pin.destino, coordinate: pin.coordenada) {
                        VStack(spacing: 2) {
                            Text(pin.icono)
                                .font(.title3)
                                .padding(7)
                                .background(pin.yaVivida ? Color.accentColor : Color.orange)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                            Text(pin.destino)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .frame(height: 360)

            List {
                Section {
                    HStack {
                        Label("\(pines.filter { $0.yaVivida }.count) vividos", systemImage: "heart.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Label("\(pines.filter { !$0.yaVivida }.count) próximos", systemImage: "airplane")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }

                    if escapadasVisibles.isEmpty {
                        Text("Añade una escapada para ver vuestros destinos en el mapa.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(escapadasVisibles) { esc in
                            NavigationLink(value: esc) {
                                HStack(spacing: 12) {
                                    Text(esc.icono)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(esc.destino)
                                            .font(.subheadline.bold())
                                        Text("\(esc.titulo) · \(esc.fechaInicio.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(esc.yaVivida ? "Vivido" : "Próximo")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((esc.yaVivida ? Color.accentColor : Color.orange).opacity(0.15))
                                        .foregroundStyle(esc.yaVivida ? Color.accentColor : Color.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    Text("Destinos desbloqueados")
                }
            }
        }
        .navigationDestination(for: Escapada.self) { esc in
            DetalleEscapadaView(escapadaId: esc.id)
        }
        .task(id: escapadasVisibles.map(\.destino).joined(separator: "|")) {
            await geocodificarDestinos()
        }
    }

    private func geocodificarDestinos() async {
        var nuevosPines: [PinDestinoMapa] = []
        let geocoder = CLGeocoder()

        for esc in escapadasVisibles {
            let textoBusqueda = esc.destino.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !textoBusqueda.isEmpty else { continue }

            if let coordRapida = coordenadaConocida(textoBusqueda) {
                nuevosPines.append(
                    PinDestinoMapa(
                        id: esc.id,
                        titulo: esc.titulo,
                        destino: esc.destino,
                        icono: esc.icono,
                        yaVivida: esc.yaVivida,
                        coordenada: coordRapida
                    )
                )
                continue
            }

            if let placemarks = try? await geocoder.geocodeAddressString(textoBusqueda),
               let loc = placemarks.first?.location {
                nuevosPines.append(
                    PinDestinoMapa(
                        id: esc.id,
                        titulo: esc.titulo,
                        destino: esc.destino,
                        icono: esc.icono,
                        yaVivida: esc.yaVivida,
                        coordenada: loc.coordinate
                    )
                )
            }
        }

        pines = nuevosPines
        if let primero = nuevosPines.first {
            posicionCamara = .region(
                MKCoordinateRegion(
                    center: primero.coordenada,
                    span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18)
                )
            )
        }
    }

    private func coordenadaConocida(_ texto: String) -> CLLocationCoordinate2D? {
        let lower = texto.lowercased()
        let catalogo: [(String, Double, Double)] = [
            ("praga", 50.0755, 14.4378),
            ("jerte", 40.2236, -5.7519),
            ("brihuega", 40.7606, -2.8692),
            ("madrid", 40.4168, -3.7038),
            ("barcelona", 41.3874, 2.1686),
            ("roma", 41.9028, 12.4964),
            ("paris", 48.8566, 2.3522),
            ("parís", 48.8566, 2.3522),
            ("londres", 51.5072, -0.1276),
            ("lisboa", 38.7223, -9.1393),
            ("oporto", 41.1579, -8.6291),
            ("cracovia", 50.0647, 19.9450),
            ("amsterdam", 52.3676, 4.9041),
            ("ámsterdam", 52.3676, 4.9041),
            ("viena", 48.2082, 16.3738),
            ("budapest", 47.4979, 19.0402),
            ("sevilla", 37.3891, -5.9845),
            ("granada", 37.1773, -3.5986),
            ("valencia", 39.4699, -0.3763),
            ("mallorca", 39.6953, 3.0176)
        ]
        for (clave, lat, lon) in catalogo where lower.contains(clave) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
}

struct WishlistDestinosView: View {
    @EnvironmentObject var store: EscapadasStore
    @State private var mostrandoNuevoDestino = false
    @State private var filtroCategoria = "Todos"
    @State private var destinoParaPlanificar: DestinoWishlist? = nil

    let categoriasFiltro = ["Todos", "Ciudad", "Playa", "Naturaleza", "Gastronomía", "Aventura"]

    private var destinosFiltrados: [DestinoWishlist] {
        if filtroCategoria == "Todos" {
            return store.wishlist
        }
        return store.wishlist.filter { $0.categoria == filtroCategoria }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.22), Color.pink.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "sparkles")
                            .font(.title2.bold())
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Futuros destinos soñados")
                            .font(.headline)
                        Text("\(store.wishlist.count) \(store.wishlist.count == 1 ? "lugar guardado" : "lugares guardados") · \(store.wishlist.filter { $0.prioridadAlta }.count) favoritos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        mostrandoNuevoDestino = true
                    } label: {
                        Label("Añadir", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categoriasFiltro, id: \.self) { cat in
                            let activa = filtroCategoria == cat
                            Button {
                                withAnimation(.snappy) {
                                    filtroCategoria = cat
                                }
                            } label: {
                                Text(cat)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(activa ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                                    .foregroundStyle(activa ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if destinosFiltrados.isEmpty {
                    ContentUnavailableView {
                        Label("Aún no hay destinos aquí", systemImage: "sparkles")
                    } description: {
                        Text("Guardad lugares que os gustaría conocer juntos algún día y convertidlos en escapada cuando llegue el momento.")
                    } actions: {
                        Button("Añadir destino deseado") {
                            mostrandoNuevoDestino = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(destinosFiltrados) { item in
                            WishlistDestinoCard(
                                item: item,
                                onToggleFavorito: {
                                    withAnimation(.snappy) {
                                        store.alternarPrioridadWishlist(item)
                                    }
                                },
                                onConvertirEnEscapada: {
                                    destinoParaPlanificar = item
                                },
                                onEliminar: {
                                    withAnimation(.snappy) {
                                        store.eliminarDestinoWishlist(item)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $mostrandoNuevoDestino) {
            NuevoDestinoWishlistSheet()
        }
        .sheet(item: $destinoParaPlanificar) { elegido in
            ConvertirWishlistAEscapadaSheet(destinoWishlist: elegido)
        }
    }
}

struct WishlistDestinoCard: View {
    let item: DestinoWishlist
    let onToggleFavorito: () -> Void
    let onConvertirEnEscapada: () -> Void
    let onEliminar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(item.icono)
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.nombreDestino)
                            .font(.headline)
                        if item.prioridadAlta {
                            Text("TOP")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.16))
                                .foregroundStyle(Color.pink)
                                .clipShape(Capsule())
                        }
                    }

                    let subtitulo = [item.paisORegion, item.categoria, item.temporadaIdeal]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")

                    if !subtitulo.isEmpty {
                        Text(subtitulo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onToggleFavorito) {
                    Image(systemName: item.prioridadAlta ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(item.prioridadAlta ? Color.pink : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            if !item.notaOEnlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let limpio = item.notaOEnlace.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: limpio), limpio.lowercased().hasPrefix("http") {
                    Link(destination: url) {
                        Label(limpio, systemImage: "safari.fill")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("“\(limpio)”")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            HStack(spacing: 10) {
                Button(action: onConvertirEnEscapada) {
                    Label("Planificar escapada", systemImage: "calendar.badge.plus")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive, action: onEliminar) {
                    Image(systemName: "trash")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

struct NuevoDestinoWishlistSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss

    @State private var nombreDestino = ""
    @State private var paisORegion = ""
    @State private var categoria = "Ciudad"
    @State private var temporadaIdeal = "Primavera"
    @State private var notaOEnlace = ""
    @State private var icono = "✨"
    @State private var prioridadAlta = true

    let iconosWishlist = ["✨", "🗼", "🏝️", "🏔️", "🍣", "🌋", "🚂", "🌅"]
    let categorias = ["Ciudad", "Playa", "Naturaleza", "Gastronomía", "Aventura"]
    let temporadas = ["Cualquier época", "Primavera", "Verano", "Otoño", "Invierno"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Icono") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(iconosWishlist, id: \.self) { em in
                                Text(em)
                                    .font(.title2)
                                    .padding(8)
                                    .background(icono == em ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture { icono = em }
                            }
                        }
                    }
                }

                Section("Destino deseado") {
                    TextField("Ciudad, isla o lugar (ej: Kioto, Dolomitas...)", text: $nombreDestino)
                    TextField("País o región (opcional)", text: $paisORegion)
                    Picker("Estilo de viaje", selection: $categoria) {
                        ForEach(categorias, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    Picker("Mejor época", selection: $temporadaIdeal) {
                        ForEach(temporadas, id: \.self) { temp in
                            Text(temp).tag(temp)
                        }
                    }
                    Toggle("Marcar como favorito prioritario", isOn: $prioridadAlta)
                }

                Section("Motivo, plan o enlace") {
                    TextField("Nota o enlace (ej: ver cerezos o https://...)", text: $notaOEnlace)
                }
            }
            .navigationTitle("Nuevo destino wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let nuevo = DestinoWishlist(
                            nombreDestino: nombreDestino.trimmingCharacters(in: .whitespacesAndNewlines),
                            paisORegion: paisORegion.trimmingCharacters(in: .whitespacesAndNewlines),
                            categoria: categoria,
                            temporadaIdeal: temporadaIdeal,
                            notaOEnlace: notaOEnlace.trimmingCharacters(in: .whitespacesAndNewlines),
                            icono: icono,
                            prioridadAlta: prioridadAlta
                        )
                        store.agregarDestinoWishlist(nuevo)
                        dismiss()
                    }
                    .disabled(nombreDestino.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ConvertirWishlistAEscapadaSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let destinoWishlist: DestinoWishlist

    @State private var titulo = ""
    @State private var fechaInicio = Date()
    @State private var fechaFin = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var quitarDeWishlist = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Convertir en escapada") {
                    TextField("Nombre del plan", text: $titulo)
                    HStack {
                        Text("Destino")
                        Spacer()
                        Text(destinoWishlist.nombreDestino)
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Fecha ida", selection: $fechaInicio, displayedComponents: .date)
                    DatePicker("Fecha vuelta", selection: $fechaFin, in: fechaInicio..., displayedComponents: .date)
                    Toggle("Quitar de la wishlist al crearla", isOn: $quitarDeWishlist)
                }
            }
            .navigationTitle("Planificar viaje")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                titulo = "Escapada a \(destinoWishlist.nombreDestino)"
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        let ideasIniciales = destinoWishlist.notaOEnlace.isEmpty ? [] : [destinoWishlist.notaOEnlace]
                        let nueva = Escapada(
                            titulo: titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? destinoWishlist.nombreDestino : titulo.trimmingCharacters(in: .whitespacesAndNewlines),
                            destino: destinoWishlist.nombreDestino,
                            fechaInicio: fechaInicio,
                            fechaFin: fechaFin,
                            icono: destinoWishlist.icono,
                            tieneVuelos: true,
                            tieneTrenes: false,
                            esSorpresa: false,
                            pistaSorpresa: "",
                            diasRevelarSorpresaAntes: 0,
                            recuerdo: "",
                            vuelos: [],
                            trenes: [],
                            checklist: [ItemChecklist(texto: "Revisar documentación", completado: false, asignadoA: "Ambos")],
                            ideas: ideasIniciales
                        )
                        store.agregarEscapada(nueva)
                        if quitarDeWishlist {
                            store.eliminarDestinoWishlist(destinoWishlist)
                        }
                        dismiss()
                    }
                }
            }
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