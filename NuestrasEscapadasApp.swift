import SwiftUI
import FirebaseCore
import FirebaseFirestore
import MapKit
import UserNotifications

// ============================================================================
// 1. MODELO DE DATOS (Compatible con Codable de Firestore)
// ============================================================================

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

struct DivisaViaje: Identifiable, Hashable {
    let id: String
    let region: String
    let nombre: String
    let simbolo: String
    let tasaAEuros: Double
}

let DIVISAS_SOPORTADAS: [DivisaViaje] = [
    // EUROPA
    DivisaViaje(id: "EUR", region: "Europa", nombre: "Euro (Zona Euro)", simbolo: "€", tasaAEuros: 1.0),
    DivisaViaje(id: "GBP", region: "Europa", nombre: "Libra esterlina (Reino Unido)", simbolo: "£", tasaAEuros: 1.19),
    DivisaViaje(id: "CHF", region: "Europa", nombre: "Franco suizo (Suiza)", simbolo: "CHF", tasaAEuros: 1.06),
    DivisaViaje(id: "CZK", region: "Europa", nombre: "Corona checa (Chequia)", simbolo: "Kč", tasaAEuros: 0.0398),
    DivisaViaje(id: "PLN", region: "Europa", nombre: "Złoty polaco (Polonia)", simbolo: "zł", tasaAEuros: 0.233),
    DivisaViaje(id: "HUF", region: "Europa", nombre: "Forinto húngaro (Hungría)", simbolo: "Ft", tasaAEuros: 0.00245),
    DivisaViaje(id: "RON", region: "Europa", nombre: "Leu rumano (Rumanía)", simbolo: "lei", tasaAEuros: 0.201),
    DivisaViaje(id: "BGN", region: "Europa", nombre: "Lev búlgaro (Bulgaria)", simbolo: "лв", tasaAEuros: 0.511),
    DivisaViaje(id: "SEK", region: "Europa", nombre: "Corona sueca (Suecia)", simbolo: "kr", tasaAEuros: 0.087),
    DivisaViaje(id: "NOK", region: "Europa", nombre: "Corona noruega (Noruega)", simbolo: "kr", tasaAEuros: 0.085),
    DivisaViaje(id: "DKK", region: "Europa", nombre: "Corona danesa (Dinamarca)", simbolo: "kr", tasaAEuros: 0.134),
    DivisaViaje(id: "ISK", region: "Europa", nombre: "Corona islandesa (Islandia)", simbolo: "kr", tasaAEuros: 0.0067),
    DivisaViaje(id: "RSD", region: "Europa", nombre: "Dinar serbio (Serbia)", simbolo: "din", tasaAEuros: 0.0085),
    DivisaViaje(id: "BAM", region: "Europa", nombre: "Marco convertible (Bosnia)", simbolo: "KM", tasaAEuros: 0.511),
    DivisaViaje(id: "ALL", region: "Europa", nombre: "Lek albanés (Albania)", simbolo: "L", tasaAEuros: 0.0101),
    DivisaViaje(id: "MKD", region: "Europa", nombre: "Denar macedonio (Macedonia)", simbolo: "ден", tasaAEuros: 0.0162),
    DivisaViaje(id: "MDL", region: "Europa", nombre: "Leu moldavo (Moldavia)", simbolo: "L", tasaAEuros: 0.052),
    DivisaViaje(id: "UAH", region: "Europa", nombre: "Grivna ucraniana (Ucrania)", simbolo: "₴", tasaAEuros: 0.022),
    DivisaViaje(id: "TRY", region: "Europa", nombre: "Lira turca (Turquía)", simbolo: "₺", tasaAEuros: 0.027),
    DivisaViaje(id: "GEL", region: "Europa", nombre: "Lari georgiano (Georgia)", simbolo: "₾", tasaAEuros: 0.34),
    
    // AMÉRICA
    DivisaViaje(id: "USD", region: "América", nombre: "Dólar estadounidense (EEUU/Ecuador)", simbolo: "$", tasaAEuros: 0.92),
    DivisaViaje(id: "CAD", region: "América", nombre: "Dólar canadiense (Canadá)", simbolo: "CA$", tasaAEuros: 0.66),
    DivisaViaje(id: "MXN", region: "América", nombre: "Peso mexicano (México)", simbolo: "MX$", tasaAEuros: 0.046),
    DivisaViaje(id: "BRL", region: "América", nombre: "Real brasileño (Brasil)", simbolo: "R$", tasaAEuros: 0.16),
    DivisaViaje(id: "ARS", region: "América", nombre: "Peso argentino (Argentina)", simbolo: "AR$", tasaAEuros: 0.00092),
    DivisaViaje(id: "CLP", region: "América", nombre: "Peso chileno (Chile)", simbolo: "CLP$", tasaAEuros: 0.00095),
    DivisaViaje(id: "COP", region: "América", nombre: "Peso colombiano (Colombia)", simbolo: "COP$", tasaAEuros: 0.00021),
    DivisaViaje(id: "PEN", region: "América", nombre: "Sol peruano (Perú)", simbolo: "S/", tasaAEuros: 0.245),
    DivisaViaje(id: "UYU", region: "América", nombre: "Peso uruguayo (Uruguay)", simbolo: "$U", tasaAEuros: 0.022),
    DivisaViaje(id: "PYG", region: "América", nombre: "Guaraní paraguayo (Paraguay)", simbolo: "₲", tasaAEuros: 0.00012),
    DivisaViaje(id: "BOB", region: "América", nombre: "Boliviano (Bolivia)", simbolo: "Bs", tasaAEuros: 0.133),
    DivisaViaje(id: "VES", region: "América", nombre: "Bolívar venezolano (Venezuela)", simbolo: "Bs.D", tasaAEuros: 0.021),
    DivisaViaje(id: "CRC", region: "América", nombre: "Colón costarricense (Costa Rica)", simbolo: "₡", tasaAEuros: 0.0018),
    DivisaViaje(id: "GTQ", region: "América", nombre: "Quetzal guatemalteco (Guatemala)", simbolo: "Q", tasaAEuros: 0.119),
    DivisaViaje(id: "HNL", region: "América", nombre: "Lempira hondureño (Honduras)", simbolo: "L", tasaAEuros: 0.037),
    DivisaViaje(id: "NIO", region: "América", nombre: "Córdoba nicaragüense (Nicaragua)", simbolo: "C$", tasaAEuros: 0.025),
    DivisaViaje(id: "PAB", region: "América", nombre: "Balboa panameño (Panamá)", simbolo: "B/.", tasaAEuros: 0.92),
    DivisaViaje(id: "DOP", region: "América", nombre: "Peso dominicano (Rep. Dominicana)", simbolo: "RD$", tasaAEuros: 0.015),
    DivisaViaje(id: "CUP", region: "América", nombre: "Peso cubano (Cuba)", simbolo: "CUP", tasaAEuros: 0.038),
    
    // ASIA
    DivisaViaje(id: "JPY", region: "Asia", nombre: "Yen japonés (Japón)", simbolo: "¥", tasaAEuros: 0.0061),
    DivisaViaje(id: "CNY", region: "Asia", nombre: "Yuan chino (China)", simbolo: "¥", tasaAEuros: 0.128),
    DivisaViaje(id: "KRW", region: "Asia", nombre: "Won surcoreano (Corea del Sur)", simbolo: "₩", tasaAEuros: 0.00066),
    DivisaViaje(id: "INR", region: "Asia", nombre: "Rupia india (India)", simbolo: "₹", tasaAEuros: 0.011),
    DivisaViaje(id: "THB", region: "Asia", nombre: "Baht tailandés (Tailandia)", simbolo: "฿", tasaAEuros: 0.027),
    DivisaViaje(id: "VND", region: "Asia", nombre: "Dong vietnamita (Vietnam)", simbolo: "₫", tasaAEuros: 0.000036),
    DivisaViaje(id: "IDR", region: "Asia", nombre: "Rupia indonesia (Indonesia/Bali)", simbolo: "Rp", tasaAEuros: 0.000058),
    DivisaViaje(id: "MYR", region: "Asia", nombre: "Ringgit malayo (Malasia)", simbolo: "RM", tasaAEuros: 0.21),
    DivisaViaje(id: "SGD", region: "Asia", nombre: "Dólar singapurense (Singapur)", simbolo: "S$", tasaAEuros: 0.69),
    DivisaViaje(id: "PHP", region: "Asia", nombre: "Peso filipino (Filipinas)", simbolo: "₱", tasaAEuros: 0.016),
    DivisaViaje(id: "TWD", region: "Asia", nombre: "Nuevo dólar taiwanés (Taiwán)", simbolo: "NT$", tasaAEuros: 0.0285),
    DivisaViaje(id: "HKD", region: "Asia", nombre: "Dólar de Hong Kong (Hong Kong)", simbolo: "HK$", tasaAEuros: 0.118),
    DivisaViaje(id: "AED", region: "Asia", nombre: "Dírham EAU (Dubái/Emiratos)", simbolo: "AED", tasaAEuros: 0.25),
    DivisaViaje(id: "SAR", region: "Asia", nombre: "Riyal saudí (Arabia Saudí)", simbolo: "SAR", tasaAEuros: 0.245),
    DivisaViaje(id: "QAR", region: "Asia", nombre: "Riyal catarí (Catar)", simbolo: "QAR", tasaAEuros: 0.252),
    DivisaViaje(id: "ILS", region: "Asia", nombre: "Nuevo séquel (Israel)", simbolo: "₪", tasaAEuros: 0.25),
    DivisaViaje(id: "JOD", region: "Asia", nombre: "Dinar jordano (Jordania)", simbolo: "JOD", tasaAEuros: 1.30),
    DivisaViaje(id: "KZT", region: "Asia", nombre: "Tenge kazajo (Kazajistán)", simbolo: "₸", tasaAEuros: 0.0019),
    DivisaViaje(id: "UZS", region: "Asia", nombre: "Som uzbeko (Uzbekistán)", simbolo: "so'm", tasaAEuros: 0.000072),
    DivisaViaje(id: "NPR", region: "Asia", nombre: "Rupia nepalí (Nepal)", simbolo: "रू", tasaAEuros: 0.0068),
    DivisaViaje(id: "LKR", region: "Asia", nombre: "Rupia de Sri Lanka (Sri Lanka)", simbolo: "Rs", tasaAEuros: 0.0031),
    DivisaViaje(id: "KHR", region: "Asia", nombre: "Riel camboyano (Camboya)", simbolo: "៛", tasaAEuros: 0.00023),
    DivisaViaje(id: "LAK", region: "Asia", nombre: "Kip laosiano (Laos)", simbolo: "₭", tasaAEuros: 0.000042)
]

struct GastoViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var concepto: String
    var importe: Double              // Importe convertido a Euros (€)
    var importeOriginal: Double      // Importe en la divisa en que se pagó
    var codigoDivisa: String         // Ej: "EUR", "CZK", "GBP", "JPY", "USD"
    var pagadoPor: String            // "Yo" o "Tú"
    var categoria: String            // "Comida", "Transporte", "Alojamiento", "Entradas", "Otros"
    var fecha: Date = Date()
    
    init(
        id: UUID = UUID(),
        concepto: String,
        importe: Double,
        importeOriginal: Double? = nil,
        codigoDivisa: String = "EUR",
        pagadoPor: String,
        categoria: String,
        fecha: Date = Date()
    ) {
        self.id = id
        self.concepto = concepto
        self.importe = importe
        self.importeOriginal = importeOriginal ?? importe
        self.codigoDivisa = codigoDivisa
        self.pagadoPor = pagadoPor
        self.categoria = categoria
        self.fecha = fecha
    }
    
    enum CodingKeys: String, CodingKey {
        case id, concepto, importe, importeOriginal, codigoDivisa, pagadoPor, categoria, fecha
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        concepto = try c.decode(String.self, forKey: .concepto)
        importe = try c.decode(Double.self, forKey: .importe)
        importeOriginal = try c.decodeIfPresent(Double.self, forKey: .importeOriginal) ?? importe
        codigoDivisa = try c.decodeIfPresent(String.self, forKey: .codigoDivisa) ?? "EUR"
        pagadoPor = try c.decode(String.self, forKey: .pagadoPor)
        categoria = try c.decode(String.self, forKey: .categoria)
        fecha = try c.decodeIfPresent(Date.self, forKey: .fecha) ?? Date()
    }
}

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

struct TrenViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var trayecto: String          // "Ida", "Vuelta"
    var operadora: String         // "Renfe", "Iryo", "Ouigo"
    var estacionOrigen: String
    var estacionDestino: String
    var fechaHoraSalida: Date
    var fechaHoraLlegada: Date
    var localizador: String
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
    var horaProgramada: Date? = nil
    var completada: Bool = false
    
    init(
        id: UUID = UUID(),
        diaIndex: Int,
        nombreSitio: String,
        urlSitio: String,
        horaProgramada: Date? = nil,
        completada: Bool = false
    ) {
        self.id = id
        self.diaIndex = diaIndex
        self.nombreSitio = nombreSitio
        self.urlSitio = urlSitio
        self.horaProgramada = horaProgramada
        self.completada = completada
    }
    
    enum CodingKeys: String, CodingKey {
        case id, diaIndex, nombreSitio, urlSitio, horaProgramada, completada
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        diaIndex = try c.decodeIfPresent(Int.self, forKey: .diaIndex) ?? 1
        nombreSitio = try c.decodeIfPresent(String.self, forKey: .nombreSitio) ?? ""
        urlSitio = try c.decodeIfPresent(String.self, forKey: .urlSitio) ?? ""
        horaProgramada = try c.decodeIfPresent(Date.self, forKey: .horaProgramada)
        completada = try c.decodeIfPresent(Bool.self, forKey: .completada) ?? false
    }
}

struct EventoLineaTemporal: Identifiable {
    let id: String
    let hora: Date
    let titulo: String
    let subtitulo: String
    let icono: String
    let esActividadEditable: Bool
    let actividadId: UUID?
    let completada: Bool
    let urlEnlace: URL?
}

struct ValoracionViaje: Codable, Hashable {
    var experienciaCiudad: Int = 0
    var museosCultura: Int = 0
    var gastronomia: Int = 0
    var alojamientoDescanso: Int = 0
    var momentosJuntos: Int = 0
    
    var mediaEstrellas: Double? {
        let notas = [
            experienciaCiudad,
            museosCultura,
            gastronomia,
            alojamientoDescanso,
            momentosJuntos
        ].filter { $0 > 0 }
        guard !notas.isEmpty else { return nil }
        let suma = notas.reduce(0, +)
        return Double(suma) / Double(notas.count)
    }
}

struct Escapada: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var titulo: String
    var destino: String
    var fechaInicio: Date
    var fechaFin: Date
    var icono: String
    var tieneVuelos: Bool = true
    var tieneTrenes: Bool = false
    var esSorpresa: Bool
    var pistaSorpresa: String
    var diasRevelarSorpresaAntes: Int = 0
    var recuerdo: String
    var momentoFavorito: String = ""
    var valoracion: ValoracionViaje = ValoracionViaje()
    var alojamiento: AlojamientoInfo = AlojamientoInfo()
    var alojamientos: [AlojamientoInfo] = []
    var gastos: [GastoViaje] = []
    var vuelos: [Vuelo]
    var trenes: [TrenViaje] = []
    var checklist: [ItemChecklist]
    var itinerario: [ActividadDia] = []
    var ideas: [String]
    var ultimoDispositivoEditor: String = ""
    
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
        tieneTrenes: Bool = false,
        esSorpresa: Bool,
        pistaSorpresa: String,
        diasRevelarSorpresaAntes: Int = 0,
        recuerdo: String,
        momentoFavorito: String = "",
        valoracion: ValoracionViaje = ValoracionViaje(),
        alojamiento: AlojamientoInfo = AlojamientoInfo(),
        alojamientos: [AlojamientoInfo] = [],
        gastos: [GastoViaje] = [],
        vuelos: [Vuelo],
        trenes: [TrenViaje] = [],
        checklist: [ItemChecklist],
        itinerario: [ActividadDia] = [],
        ideas: [String],
        ultimoDispositivoEditor: String = ""
    ) {
        self.id = id
        self.titulo = titulo
        self.destino = destino
        self.fechaInicio = fechaInicio
        self.fechaFin = fechaFin
        self.icono = icono
        self.tieneVuelos = tieneVuelos
        self.tieneTrenes = tieneTrenes
        self.esSorpresa = esSorpresa
        self.pistaSorpresa = pistaSorpresa
        self.diasRevelarSorpresaAntes = max(0, diasRevelarSorpresaAntes)
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
        self.vuelos = vuelos
        self.trenes = trenes
        self.checklist = checklist
        self.itinerario = itinerario
        self.ideas = ideas
        self.ultimoDispositivoEditor = ultimoDispositivoEditor
    }
    
    enum CodingKeys: String, CodingKey {
        case id, titulo, destino, fechaInicio, fechaFin, icono, tieneVuelos, tieneTrenes, esSorpresa, pistaSorpresa
        case diasRevelarSorpresaAntes, recuerdo, momentoFavorito, valoracion, alojamiento, alojamientos, gastos, vuelos, trenes, checklist, itinerario, ideas, ultimoDispositivoEditor
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
        let alojLegacy = try c.decodeIfPresent(AlojamientoInfo.self, forKey: .alojamiento) ?? AlojamientoInfo()
        alojamiento = alojLegacy
        let listaAloj = try c.decodeIfPresent([AlojamientoInfo].self, forKey: .alojamientos) ?? []
        if !listaAloj.isEmpty {
            alojamientos = listaAloj
        } else if alojLegacy.tieneDatos {
            alojamientos = [alojLegacy]
        } else {
            alojamientos = []
        }
        gastos = try c.decodeIfPresent([GastoViaje].self, forKey: .gastos) ?? []
        checklist = try c.decodeIfPresent([ItemChecklist].self, forKey: .checklist) ?? []
        itinerario = try c.decodeIfPresent([ActividadDia].self, forKey: .itinerario) ?? []
        ideas = try c.decodeIfPresent([String].self, forKey: .ideas) ?? []
        ultimoDispositivoEditor = try c.decodeIfPresent(String.self, forKey: .ultimoDispositivoEditor) ?? ""
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
        
        if code.count >= 4, let online = await consultarWebEstadoVuelo(
            codigoVuelo: code,
            aerolineaDefault: infoAerolinea.nombre,
            urlReservaDefault: infoAerolinea.url,
            webEstado: webFlightAware
        ) {
            return online
        }
        
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
            
            let parsedObject = try JSONSerialization.jsonObject(with: data)
            guard let json = parsedObject as? [String: Any],
                  let resp = json["response"] as? [String: Any],
                  let flightroute = resp["flightroute"] as? [String: Any] else {
                return nil
            }
            
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
    private let deviceIdKey = "nuestras_escapadas_device_id_v1"
    private var primeraCargaSala = true
    private let deviceId: String
    
    init() {
        if let guardadoDevice = UserDefaults.standard.string(forKey: deviceIdKey), !guardadoDevice.isEmpty {
            self.deviceId = guardadoDevice
        } else {
            let nuevo = UUID().uuidString
            UserDefaults.standard.set(nuevo, forKey: deviceIdKey)
            self.deviceId = nuevo
        }
        let guardado = UserDefaults.standard.string(forKey: "codigo_pareja_ios") ?? "VIAJE-2026"
        self.codigoPareja = guardado
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
                
                let eraPrimera = self.primeraCargaSala
                self.primeraCargaSala = false
                
                if !eraPrimera {
                    for remota in remotas {
                        if !remota.ultimoDispositivoEditor.isEmpty && remota.ultimoDispositivoEditor != self.deviceId {
                            if let previa = self.escapadas.first(where: { $0.id == remota.id }), previa.ideas != remota.ideas {
                                self.enviarNotificacionCambioIdeas(escapada: remota)
                            }
                        }
                    }
                }
                
                self.escapadas = remotas
                self.guardarCopiaLocal()
            }
        }
    }
    
    private func enviarNotificacionCambioIdeas(escapada: Escapada) {
        let content = UNMutableNotificationContent()
        content.title = "💡 Nuevo cambio en \(escapada.titulo)"
        content.body = "Tu pareja ha actualizado las notas rápidas e ideas de \(escapada.destino)."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
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
    
    func actualizarEscapada(_ editada: Escapada) {
        if let idx = escapadas.firstIndex(where: { $0.id == editada.id }) {
            escapadas[idx] = editada
        } else {
            escapadas.append(editada)
        }
        guardarCopiaLocal()
        guardarEnFirestore(editada)
    }
    
    func eliminarEscapada(_ escapada: Escapada) {
        escapadas.removeAll { $0.id == escapada.id }
        guardarCopiaLocal()
        eliminarDeFirestore(escapada)
    }
    
    private func guardarEnFirestore(_ escapada: Escapada) {
        guard let db = db else { return }
        var copiaConAutor = escapada
        copiaConAutor.ultimoDispositivoEditor = deviceId
        do {
            try db.collection("parejas")
                .document(codigoPareja)
                .collection("escapadas")
                .document(copiaConAutor.id.uuidString)
                .setData(from: copiaConAutor, merge: false)
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
    
    private func guardarCopiaLocal() {
        do {
            let data = try JSONEncoder().encode(escapadas)
            UserDefaults.standard.set(data, forKey: localBackupKey)
        } catch {
            // Ignorar error de respaldo local
        }
    }
    
    private func cargarCopiaLocal() {
        guard let data = UserDefaults.standard.data(forKey: localBackupKey) else { return }
        do {
            escapadas = try JSONDecoder().decode([Escapada].self, from: data)
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
                tieneTrenes: false,
                esSorpresa: true,
                pistaSorpresa: "Abrigo cómodo y ganas de desconectar",
                diasRevelarSorpresaAntes: 3,
                recuerdo: "",
                vuelos: [],
                checklist: [
                    ItemChecklist(texto: "Calzado cómodo", completado: false, asignadoA: "Ambos")
                ],
                ideas: []
            )
        ]
        
        escapadas = ejemplos
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
    @State private var incluirHoraSitio = false
    @State private var horaNuevoSitio = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var verSoloPendientesTimeline = false
    @State private var nuevoItemTexto = ""
    @State private var nuevoItemAsignado = "Ambos"
    @State private var nuevaIdeaTexto = ""
    @State private var mostrandoAgregarVuelo = false
    @State private var mostrandoAgregarTren = false
    @State private var alojamientoEnEdicion: AlojamientoInfo? = nil
    @State private var mostrandoNuevoAlojamiento = false
    @State private var mostrandoAgregarGasto = false
    @State private var codigoAlojamientoCopiado: UUID? = nil
    
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
                                Toggle("Añadir hora", isOn: $incluirHoraSitio)
                                    .font(.caption.weight(.medium))
                                if incluirHoraSitio {
                                    DatePicker("", selection: $horaNuevoSitio, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                            }
                            
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
                                    var horaFinal: Date? = nil
                                    if incluirHoraSitio {
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: horaNuevoSitio)
                                        let baseFecha = escapada.fechaParaDia(diaSeleccionado)
                                        horaFinal = Calendar.current.date(bySettingHour: comps.hour ?? 11, minute: comps.minute ?? 0, second: 0, of: baseFecha)
                                    }
                                    var copia = escapada
                                    copia.itinerario.append(
                                        ActividadDia(
                                            diaIndex: diaSeleccionado,
                                            nombreSitio: nombre,
                                            urlSitio: urlLimpia,
                                            horaProgramada: horaFinal,
                                            completada: false
                                        )
                                    )
                                    store.actualizarEscapada(copia)
                                    nuevoSitioNombre = ""
                                    nuevoSitioURL = ""
                                    incluirHoraSitio = false
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                .disabled(nuevoSitioNombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Línea temporal interactiva del día seleccionado
                        let eventosDia = construirEventosLineaTemporal(para: escapada, dia: diaSeleccionado)
                        let eventosVisibles = verSoloPendientesTimeline ? eventosDia.filter { !$0.completada } : eventosDia
                        
                        if !eventosDia.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Línea temporal del Día \(diaSeleccionado)", systemImage: "clock.arrow.circlepath")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.accentColor)
                                    Spacer()
                                    Button {
                                        verSoloPendientesTimeline.toggle()
                                    } label: {
                                        Text(verSoloPendientesTimeline ? "Ver todos" : "Solo pendientes")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                ForEach(eventosVisibles) { ev in
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(spacing: 4) {
                                            Text(ev.hora.formatted(date: .omitted, time: .shortened))
                                                .font(.caption2.bold().monospacedDigit())
                                                .foregroundStyle(ev.completada ? .secondary : Color.accentColor)
                                            Circle()
                                                .fill(ev.completada ? Color.green : Color.accentColor)
                                                .frame(width: 8, height: 8)
                                        }
                                        .frame(width: 52)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Text("\(ev.icono) \(ev.titulo)")
                                                    .font(.subheadline.weight(.medium))
                                                    .strikethrough(ev.completada)
                                                    .foregroundStyle(ev.completada ? .secondary : .primary)
                                                Spacer()
                                                if ev.esActividadEditable, let actId = ev.actividadId {
                                                    Button {
                                                        alternarCompletadaActividad(escapada: escapada, actividadId: actId)
                                                    } label: {
                                                        Image(systemName: ev.completada ? "checkmark.circle.fill" : "circle")
                                                            .foregroundStyle(ev.completada ? .green : .secondary)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            if !ev.subtitulo.isEmpty {
                                                Text(ev.subtitulo)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let url = ev.urlEnlace {
                                                Link(destination: url) {
                                                    Label("Abrir enlace", systemImage: "safari")
                                                        .font(.caption2.bold())
                                                }
                                            }
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                            .padding(.top, 6)
                        }
                        
                        let actividadesDelDia = escapada.itinerario.filter { $0.diaIndex == diaSeleccionado }
                        if actividadesDelDia.isEmpty {
                            Text("Aún no hay sitios planeados para el Día \(diaSeleccionado).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(actividadesDelDia) { act in
                                HStack(spacing: 10) {
                                    Button {
                                        alternarCompletadaActividad(escapada: escapada, actividadId: act.id)
                                    } label: {
                                        Image(systemName: act.completada ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(act.completada ? .green : Color.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(act.nombreSitio)
                                            .font(.subheadline.weight(.medium))
                                            .strikethrough(act.completada)
                                            .foregroundStyle(act.completada ? .secondary : .primary)
                                        if let hora = act.horaProgramada {
                                            Text("🕒 \(hora.formatted(date: .omitted, time: .shortened))")
                                                .font(.caption2.bold())
                                                .foregroundStyle(Color.accentColor)
                                        }
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
                    
                    // Sección Trenes (independiente de vuelos, con páginas de trenes españolas)
                    if escapada.tieneTrenes || !escapada.trenes.isEmpty {
                        Section {
                            if escapada.trenes.isEmpty {
                                Text("Sin billetes de tren añadidos")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(escapada.trenes) { tren in
                                    TrenCardView(tren: tren)
                                }
                                .onDelete { offsets in
                                    var copia = escapada
                                    copia.trenes.remove(atOffsets: offsets)
                                    store.actualizarEscapada(copia)
                                }
                            }
                            
                            Button {
                                mostrandoAgregarTren = true
                            } label: {
                                Label("Añadir billete de tren", systemImage: "tram.circle.fill")
                            }
                            
                            HStack(spacing: 8) {
                                Text("Webs trenes:")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Link("Renfe", destination: URL(string: "https://www.renfe.com/es/es")!)
                                    .font(.caption2.bold())
                                Link("Iryo", destination: URL(string: "https://iryo.eu/es")!)
                                    .font(.caption2.bold())
                                Link("Ouigo", destination: URL(string: "https://www.ouigo.com/es")!)
                                    .font(.caption2.bold())
                            }
                        } header: {
                            Text("Trenes y billetes")
                        }
                    } else {
                        Section {
                            Button {
                                var copia = escapada
                                copia.tieneTrenes = true
                                store.actualizarEscapada(copia)
                                mostrandoAgregarTren = true
                            } label: {
                                Label("Este viaje no tiene trenes · Activar sección de trenes", systemImage: "tram.fill")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Sección Alojamientos (permite añadir más de uno por viaje)
                    Section {
                        if escapada.alojamientos.isEmpty {
                            Button {
                                mostrandoNuevoAlojamiento = true
                            } label: {
                                Label("Añadir hotel, apartamento o alojamiento", systemImage: "bed.double.fill")
                            }
                        } else {
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
                                        }
                                        Spacer()
                                        Button("Editar") {
                                            alojamientoEnEdicion = aloj
                                        }
                                        .font(.caption.bold())
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Label("Check-in: \(aloj.horaCheckIn)", systemImage: "arrow.down.right.circle")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                            .clipShape(Capsule())
                                        
                                        Label("Check-out: \(aloj.horaCheckOut)", systemImage: "arrow.up.right.circle")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                            .clipShape(Capsule())
                                    }
                                    
                                    HStack(spacing: 8) {
                                        if !aloj.codigoReserva.isEmpty {
                                            Button {
                                                UIPasteboard.general.string = aloj.codigoReserva
                                                codigoAlojamientoCopiado = aloj.id
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                    codigoAlojamientoCopiado = nil
                                                }
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Text("Ref: \(aloj.codigoReserva)")
                                                        .font(.caption.monospaced().bold())
                                                    Image(systemName: codigoAlojamientoCopiado == aloj.id ? "checkmark" : "doc.on.doc")
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
                                        
                                        if let reservaUrl = URL(string: aloj.urlReserva), !aloj.urlReserva.isEmpty {
                                            Link(destination: reservaUrl) {
                                                Image(systemName: "safari")
                                                    .font(.caption.bold())
                                            }
                                            .buttonStyle(.bordered)
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
                                Label("Añadir otro alojamiento", systemImage: "plus.circle.fill")
                                    .font(.caption.bold())
                            }
                        }
                    } header: {
                        Text(escapada.alojamientos.count > 1 ? "Alojamientos (\(escapada.alojamientos.count))" : "Alojamiento")
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
                
                // Sección Gastos Compartidos
                Section {
                    let totalGastos = escapada.gastos.reduce(0) { $0 + $1.importe }
                    let pagadoYo = escapada.gastos.filter { $0.pagadoPor == "Yo" }.reduce(0) { $0 + $1.importe }
                    let pagadoTu = escapada.gastos.filter { $0.pagadoPor == "Tú" }.reduce(0) { $0 + $1.importe }
                    let mitad = totalGastos / 2.0
                    let diferencia = pagadoYo - mitad
                    
                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TOTAL DEL VIAJE")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.2f €", totalGastos))
                                    .font(.title2.bold().monospacedDigit())
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Yo: \(String(format: "%.2f €", pagadoYo))")
                                    .font(.caption.weight(.medium))
                                Text("Tú: \(String(format: "%.2f €", pagadoTu))")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        if totalGastos > 0 {
                            HStack {
                                Image(systemName: abs(diferencia) < 0.01 ? "checkmark.seal.fill" : "arrow.left.arrow.right.circle.fill")
                                    .foregroundStyle(abs(diferencia) < 0.01 ? .green : Color.accentColor)
                                if abs(diferencia) < 0.01 {
                                    Text("¡Estáis en paz al 50%!")
                                        .font(.caption.bold())
                                } else if diferencia > 0 {
                                    Text("Tú le debes \(String(format: "%.2f €", diferencia)) a Yo")
                                        .font(.caption.bold())
                                } else {
                                    Text("Yo le debe \(String(format: "%.2f €", abs(diferencia))) a Tú")
                                        .font(.caption.bold())
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.vertical, 4)
                    
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
                            VStack(alignment: .trailing, spacing: 2) {
                                if gasto.codigoDivisa != "EUR" {
                                    Text(String(format: "%.2f %@", gasto.importeOriginal, gasto.codigoDivisa))
                                        .font(.subheadline.bold().monospacedDigit())
                                    Text(String(format: "≈ %.2f €", gasto.importe))
                                        .font(.caption2.bold().monospacedDigit())
                                        .foregroundStyle(Color.accentColor)
                                } else {
                                    Text(String(format: "%.2f €", gasto.importe))
                                        .font(.subheadline.bold().monospacedDigit())
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
                        mostrandoAgregarGasto = true
                    } label: {
                        Label("Añadir gasto compartido", systemImage: "eurosign.circle.fill")
                    }
                } header: {
                    Text("Gastos compartidos")
                }
                
                // Sección Recuerdo Ampliada + Valoración (Solo visible cuando la escapada ya ha finalizado)
                if escapada.yaVivida {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Puntuación del viaje (1 a 5)")
                                    .font(.subheadline.bold())
                                Spacer()
                                if let media = escapada.valoracion.mediaEstrellas {
                                    HStack(spacing: 3) {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                        Text(String(format: "%.1f / 5", media))
                                            .font(.caption.bold().monospacedDigit())
                                    }
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.14))
                                    .clipShape(Capsule())
                                }
                            }
                            
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
            .sheet(isPresented: $mostrandoAgregarTren) {
                AgregarTrenSheet(escapada: escapada)
            }
            .sheet(isPresented: $mostrandoNuevoAlojamiento) {
                EditarAlojamientoSheet(escapada: escapada, alojamientoExistente: nil)
            }
            .sheet(item: $alojamientoEnEdicion) { alojEditar in
                EditarAlojamientoSheet(escapada: escapada, alojamientoExistente: alojEditar)
            }
            .sheet(isPresented: $mostrandoAgregarGasto) {
                AgregarGastoSheet(escapada: escapada)
            }
        }
    }
    
    private func iconoCategoriaGasto(_ categoria: String) -> String {
        switch categoria {
        case "Comida": return "🍽️"
        case "Transporte": return "🚆"
        case "Alojamiento": return "🛏️"
        case "Entradas": return "🎟️"
        default: return "🛍️"
        }
    }
    
    private func alternarCompletadaActividad(escapada: Escapada, actividadId: UUID) {
        var copia = escapada
        if let idx = copia.itinerario.firstIndex(where: { $0.id == actividadId }) {
            copia.itinerario[idx].completada.toggle()
            store.actualizarEscapada(copia)
        }
    }
    
    private func construirEventosLineaTemporal(para escapada: Escapada, dia: Int) -> [EventoLineaTemporal] {
        let cal = Calendar.current
        let fechaDia = escapada.fechaParaDia(dia)
        var eventos: [EventoLineaTemporal] = []
        
        for vuelo in escapada.vuelos where cal.isDate(vuelo.fechaHoraSalida, inSameDayAs: fechaDia) {
            eventos.append(
                EventoLineaTemporal(
                    id: "vuelo-\(vuelo.id.uuidString)",
                    hora: vuelo.fechaHoraSalida,
                    titulo: "\(vuelo.origen) → \(vuelo.destino) (\(vuelo.aerolinea))",
                    subtitulo: vuelo.terminalPuerta.isEmpty ? "Vuelo \(vuelo.trayecto)" : "\(vuelo.trayecto) · \(vuelo.terminalPuerta)",
                    icono: "✈️",
                    esActividadEditable: false,
                    actividadId: nil,
                    completada: false,
                    urlEnlace: URL(string: vuelo.urlReserva)
                )
            )
        }
        
        for tren in escapada.trenes where cal.isDate(tren.fechaHoraSalida, inSameDayAs: fechaDia) {
            eventos.append(
                EventoLineaTemporal(
                    id: "tren-\(tren.id.uuidString)",
                    hora: tren.fechaHoraSalida,
                    titulo: "\(tren.estacionOrigen) → \(tren.estacionDestino)",
                    subtitulo: "\(tren.operadora) · \(tren.trayecto)",
                    icono: "🚂",
                    esActividadEditable: false,
                    actividadId: nil,
                    completada: false,
                    urlEnlace: URL(string: tren.urlReserva)
                )
            )
        }
        
        if dia == 1, let aloj = escapada.alojamientos.first,
           let horaIn = parsearHoraTexto(aloj.horaCheckIn, sobre: fechaDia) {
            eventos.append(
                EventoLineaTemporal(
                    id: "checkin-\(aloj.id.uuidString)",
                    hora: horaIn,
                    titulo: "Check-in: \(aloj.nombre.isEmpty ? "Alojamiento" : aloj.nombre)",
                    subtitulo: aloj.direccion,
                    icono: "🔑",
                    esActividadEditable: false,
                    actividadId: nil,
                    completada: false,
                    urlEnlace: URL(string: aloj.urlReserva)
                )
            )
        }
        
        if dia == escapada.totalDias, let aloj = escapada.alojamientos.first,
           let horaOut = parsearHoraTexto(aloj.horaCheckOut, sobre: fechaDia) {
            eventos.append(
                EventoLineaTemporal(
                    id: "checkout-\(aloj.id.uuidString)",
                    hora: horaOut,
                    titulo: "Check-out: \(aloj.nombre.isEmpty ? "Alojamiento" : aloj.nombre)",
                    subtitulo: aloj.direccion,
                    icono: "🧳",
                    esActividadEditable: false,
                    actividadId: nil,
                    completada: false,
                    urlEnlace: URL(string: aloj.urlReserva)
                )
            )
        }
        
        for act in escapada.itinerario where act.diaIndex == dia {
            let horaAct = act.horaProgramada ?? cal.date(bySettingHour: 12, minute: 0, second: 0, of: fechaDia) ?? fechaDia
            eventos.append(
                EventoLineaTemporal(
                    id: "act-\(act.id.uuidString)",
                    hora: horaAct,
                    titulo: act.nombreSitio,
                    subtitulo: act.horaProgramada == nil ? "Sin hora fija (12:00 aprox.)" : "Plan del día",
                    icono: "📍",
                    esActividadEditable: true,
                    actividadId: act.id,
                    completada: act.completada,
                    urlEnlace: URL(string: act.urlSitio)
                )
            )
        }
        
        return eventos.sorted { $0.hora < $1.hora }
    }
    
    private func parsearHoraTexto(_ texto: String, sobre fecha: Date) -> Date? {
        let partes = texto.split(separator: ":")
        guard partes.count == 2,
              let h = Int(partes[0].trimmingCharacters(in: .whitespaces)),
              let m = Int(partes[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: fecha)
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
    let tren: TrenViaje
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
                
                Text("🚂 \(tren.operadora)")
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
                
                if let url = URL(string: tren.urlReserva), !tren.urlReserva.isEmpty {
                    Link(destination: url) {
                        Label("Billete", systemImage: "arrow.up.right.square")
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
// 8. FORMULARIOS MODALES (Nueva Escapada, Añadir Vuelo, Tren, Alojamiento, Gasto)
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
    
    // Opción 1: Vuelos al crear la escapada
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
    
    // Opción 2: Trenes al crear la escapada (independiente de vuelos)
    @State private var tieneTrenes = false
    @State private var operadoraTren = "Renfe"
    @State private var estacionOrigenTren = ""
    @State private var estacionDestinoTren = ""
    @State private var localizadorTren = ""
    @State private var horaSalidaTren = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    
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
                    Toggle("🚂 ¿Este viaje incluye trenes?", isOn: $tieneTrenes)
                    
                    if tieneTrenes {
                        Picker("Operadora española", selection: $operadoraTren) {
                            Text("Renfe (AVE / Avlo / Alvia)").tag("Renfe")
                            Text("Iryo").tag("Iryo")
                            Text("Ouigo España").tag("Ouigo")
                        }
                        
                        TextField("Estación origen (ej: Madrid Atocha)", text: $estacionOrigenTren)
                        TextField("Estación destino (ej: Sevilla Santa Justa)", text: $estacionDestinoTren)
                        TextField("Localizador billete", text: $localizadorTren)
                            .autocapitalization(.allCharacters)
                        DatePicker("Hora de salida", selection: $horaSalidaTren, displayedComponents: .hourAndMinute)
                        
                        HStack(spacing: 10) {
                            Link("Web Renfe", destination: URL(string: "https://www.renfe.com/es/es")!)
                            Text("·")
                            Link("Web Iryo", destination: URL(string: "https://iryo.eu/es")!)
                            Text("·")
                            Link("Web Ouigo", destination: URL(string: "https://www.ouigo.com/es")!)
                        }
                        .font(.caption.bold())
                    }
                } header: {
                    Text("Trenes")
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
                        
                        var trenesIniciales: [TrenViaje] = []
                        if tieneTrenes && (!estacionOrigenTren.isEmpty || !estacionDestinoTren.isEmpty || !localizadorTren.isEmpty) {
                            let compsTren = Calendar.current.dateComponents([.hour, .minute], from: horaSalidaTren)
                            let salidaTrenExacta = Calendar.current.date(bySettingHour: compsTren.hour ?? 10, minute: compsTren.minute ?? 0, second: 0, of: fechaInicio) ?? fechaInicio
                            let llegadaTrenExacta = Calendar.current.date(byAdding: .minute, value: 150, to: salidaTrenExacta) ?? salidaTrenExacta
                            let urlWebTren = operadoraTren == "Iryo" ? "https://iryo.eu/es" : (operadoraTren == "Ouigo" ? "https://www.ouigo.com/es" : "https://www.renfe.com/es/es")
                            
                            trenesIniciales.append(
                                TrenViaje(
                                    trayecto: "Ida",
                                    operadora: operadoraTren,
                                    estacionOrigen: estacionOrigenTren.isEmpty ? "Origen" : estacionOrigenTren,
                                    estacionDestino: estacionDestinoTren.isEmpty ? destino : estacionDestinoTren,
                                    fechaHoraSalida: salidaTrenExacta,
                                    fechaHoraLlegada: llegadaTrenExacta,
                                    localizador: localizadorTren.uppercased(),
                                    urlReserva: urlWebTren
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
                            trenes: trenesIniciales,
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

struct AgregarTrenSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    
    @State private var trayecto = "Ida"
    @State private var operadora = "Renfe"
    @State private var estacionOrigen = ""
    @State private var estacionDestino = ""
    @State private var localizador = ""
    @State private var salida = Date()
    @State private var llegada = Date()
    @State private var urlReserva = "https://www.renfe.com/es/es"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Billete de tren") {
                    Picker("Trayecto", selection: $trayecto) {
                        Text("Ida").tag("Ida")
                        Text("Vuelta").tag("Vuelta")
                    }
                    Picker("Operadora española", selection: $operadora) {
                        Text("Renfe").tag("Renfe")
                        Text("Iryo").tag("Iryo")
                        Text("Ouigo").tag("Ouigo")
                    }
                    .onChange(of: operadora) { _, nuevaOp in
                        if nuevaOp == "Iryo" { urlReserva = "https://iryo.eu/es" }
                        else if nuevaOp == "Ouigo" { urlReserva = "https://www.ouigo.com/es" }
                        else { urlReserva = "https://www.renfe.com/es/es" }
                    }
                    TextField("Estación origen (ej: Madrid Atocha)", text: $estacionOrigen)
                    TextField("Estación destino (ej: Valencia Joaquín Sorolla)", text: $estacionDestino)
                    TextField("Localizador", text: $localizador)
                        .autocapitalization(.allCharacters)
                    DatePicker("Salida", selection: $salida)
                    DatePicker("Llegada", selection: $llegada)
                }
                
                Section("Páginas oficiales de trenes en España") {
                    Link("🚄 Renfe (renfe.com)", destination: URL(string: "https://www.renfe.com/es/es")!)
                    Link("🚄 Iryo (iryo.eu)", destination: URL(string: "https://iryo.eu/es")!)
                    Link("🚄 Ouigo (ouigo.com)", destination: URL(string: "https://www.ouigo.com/es")!)
                }
            }
            .navigationTitle("Añadir tren")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                salida = escapada.fechaInicio
                llegada = escapada.fechaInicio.addingTimeInterval(9000)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let tren = TrenViaje(
                            trayecto: trayecto,
                            operadora: operadora,
                            estacionOrigen: estacionOrigen,
                            estacionDestino: estacionDestino,
                            fechaHoraSalida: salida,
                            fechaHoraLlegada: llegada,
                            localizador: localizador.uppercased(),
                            urlReserva: urlReserva
                        )
                        var copia = escapada
                        copia.tieneTrenes = true
                        copia.trenes.append(tren)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(estacionOrigen.isEmpty || estacionDestino.isEmpty)
                }
            }
        }
    }
}

struct YaVividoView: View {
    @EnvironmentObject var store: EscapadasStore
    @State private var ordenarPorRanking = false
    @State private var filtroEstrellasMin: Int = 0
    
    private var top3Escapadas: [Escapada] {
        store.escapadasPasadas
            .filter { ($0.valoracion.mediaEstrellas ?? 0) > 0 }
            .sorted {
                let m1 = $0.valoracion.mediaEstrellas ?? 0
                let m2 = $1.valoracion.mediaEstrellas ?? 0
                if m1 == m2 { return $0.fechaInicio > $1.fechaInicio }
                return m1 > m2
            }
            .prefix(3)
            .map { $0 }
    }
    
    private var escapadasFiltradas: [Escapada] {
        let base = store.escapadasPasadas.filter { esc in
            if filtroEstrellasMin == 0 { return true }
            let media = esc.valoracion.mediaEstrellas ?? 0
            return media >= Double(filtroEstrellasMin)
        }
        if ordenarPorRanking {
            return base.sorted {
                let m1 = $0.valoracion.mediaEstrellas ?? 0
                let m2 = $1.valoracion.mediaEstrellas ?? 0
                if m1 == m2 { return $0.fechaInicio > $1.fechaInicio }
                return m1 > m2
            }
        }
        return base
    }
    
    var body: some View {
        List {
            if store.escapadasPasadas.isEmpty {
                ContentUnavailableView("Aún no hay recuerdos", systemImage: "photo.on.rectangle.angled")
            } else {
                // Podio Top 3 de mejores escapadas puntuadas
                if !top3Escapadas.isEmpty {
                    Section {
                        ForEach(Array(top3Escapadas.enumerated()), id: \.element.id) { idx, esc in
                            NavigationLink(value: esc) {
                                HStack(spacing: 12) {
                                    Text(medallaRanking(idx))
                                        .font(.title3)
                                    Text(esc.icono)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(esc.titulo)
                                            .font(.subheadline.bold())
                                        Text(esc.destino)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let media = esc.valoracion.mediaEstrellas {
                                        HStack(spacing: 3) {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                            Text(String(format: "%.1f", media))
                                                .font(.caption.bold().monospacedDigit())
                                        }
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.14))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("🏆 Podio Top 3 · Mejores escapadas")
                    }
                }
                
                // Controles de ordenación y filtro por estrellas
                Section {
                    Picker("Ordenar por", selection: $ordenarPorRanking) {
                        Text("Más recientes").tag(false)
                        Text("Mejor puntuación").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Filtro de estrellas", selection: $filtroEstrellasMin) {
                        Text("Todas").tag(0)
                        Text("3★+").tag(3)
                        Text("4★+").tag(4)
                        Text("4.5★+").tag(5)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    if escapadasFiltradas.isEmpty {
                        Text("Ninguna escapada cumple ese filtro de estrellas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(escapadasFiltradas) { esc in
                            NavigationLink(value: esc) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("\(esc.icono) \(esc.titulo)")
                                            .font(.headline)
                                        Spacer()
                                        if let media = esc.valoracion.mediaEstrellas {
                                            HStack(spacing: 3) {
                                                Image(systemName: "star.fill")
                                                    .font(.caption2)
                                                Text(String(format: "%.1f", media))
                                                    .font(.caption.bold().monospacedDigit())
                                            }
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.orange.opacity(0.14))
                                            .clipShape(Capsule())
                                        } else {
                                            Text("Sin puntuar")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Text("📍 \(esc.destino) · \(esc.fechaInicio.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    let totalViaje = esc.gastos.reduce(0) { $0 + $1.importe }
                                    HStack {
                                        Label("Total gastado", systemImage: "eurosign.circle.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.accentColor)
                                        Spacer()
                                        Text(String(format: "%.2f €", totalViaje))
                                            .font(.caption.bold().monospacedDigit())
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .padding(.vertical, 2)
                                    
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
                } header: {
                    Text("Historial (\(escapadasFiltradas.count))")
                }
            }
        }
        .navigationDestination(for: Escapada.self) { esc in
            DetalleEscapadaView(escapadaId: esc.id)
        }
    }
    
    private func medallaRanking(_ indice: Int) -> String {
        switch indice {
        case 0: return "🥇"
        case 1: return "🥈"
        default: return "🥉"
        }
    }
}

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
                        let infoActualizada = AlojamientoInfo(
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
                            copia.alojamientos[idx] = infoActualizada
                        } else {
                            copia.alojamientos.append(infoActualizada)
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

struct AgregarGastoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    
    @State private var concepto = ""
    @State private var importeTexto = ""
    @State private var regionFiltro = "Europa"
    @State private var divisaSeleccionada: DivisaViaje = DIVISAS_SOPORTADAS[0]
    @State private var pagadoPor = "Yo"
    @State private var categoria = "Comida"
    
    let categorias = ["Comida", "Transporte", "Alojamiento", "Entradas", "Otros"]
    let regiones = ["Europa", "América", "Asia"]
    
    private var divisasDeRegion: [DivisaViaje] {
        DIVISAS_SOPORTADAS.filter { $0.region == regionFiltro }
    }
    
    private var importeNumerico: Double {
        let limpio = importeTexto.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(limpio) ?? 0
    }
    
    private var equivalenteEuros: Double {
        importeNumerico * divisaSeleccionada.tasaAEuros
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle del gasto") {
                    TextField("Concepto (ej: Cena en el centro)", text: $concepto)
                    
                    Picker("Continente de la moneda", selection: $regionFiltro) {
                        ForEach(regiones, id: \.self) { reg in
                            Text(reg).tag(reg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: regionFiltro) { _, nuevaRegion in
                        if let primera = DIVISAS_SOPORTADAS.first(where: { $0.region == nuevaRegion }) {
                            divisaSeleccionada = primera
                        }
                    }
                    
                    Picker("Divisa pagada", selection: $divisaSeleccionada) {
                        ForEach(divisasDeRegion) { div in
                            Text("\(div.id) · \(div.nombre) (\(div.simbolo))").tag(div)
                        }
                    }
                    
                    TextField("Importe en \(divisaSeleccionada.id) (ej: 42,50)", text: $importeTexto)
                        .keyboardType(.decimalPad)
                    
                    if divisaSeleccionada.id != "EUR" && importeNumerico > 0 {
                        HStack {
                            Text("Conversión a Euros:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f %@ = %.2f €", importeNumerico, divisaSeleccionada.id, equivalenteEuros))
                                .font(.caption.bold())
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        guard importeNumerico > 0 else { return }
                        let nuevoGasto = GastoViaje(
                            concepto: concepto.trimmingCharacters(in: .whitespacesAndNewlines),
                            importe: equivalenteEuros,
                            importeOriginal: importeNumerico,
                            codigoDivisa: divisaSeleccionada.id,
                            pagadoPor: pagadoPor,
                            categoria: categoria
                        )
                        var copia = escapada
                        copia.gastos.append(nuevoGasto)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(concepto.trimmingCharacters(in: .whitespaces).isEmpty || importeNumerico <= 0)
                }
            }
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