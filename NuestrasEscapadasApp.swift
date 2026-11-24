import SwiftUI
import FirebaseCore
import FirebaseFirestore
import MapKit
import PhotosUI
import UserNotifications

// ============================================================================
// 1. MODELO DE DATOS (Compatible con Codable de Firestore)
// ============================================================================

struct AlojamientoInfo: Codable, Hashable {
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
}

struct GastoViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var concepto: String
    var importe: Double
    var importeOriginal: Double?
    var monedaOriginal: String?
    var pagadoPor: String
    var categoria: String
    var fecha: Date = Date()
}

struct RetoFotografico: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var titulo: String
    var completado: Bool = false
    var completadoPor: String = ""
    var fotoBase64: String? = nil
}

struct DeseoViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var destino: String
    var nota: String = ""
    var urlReferencia: String = ""
    var icono: String = "✨"
    var agregadoPor: String = "Ambos"
    var fechaAgregado: Date = Date()
}

struct DocumentoBoveda: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var titulo: String
    var tipo: String
    var codigoOUrl: String = ""
    var imagenBase64: String? = nil
    var fechaAgregado: Date = Date()
}

struct TrenViaje: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var trayecto: String
    var origen: String
    var destino: String
    var fechaHoraSalida: Date
    var fechaHoraLlegada: Date
    var operadora: String
    var numeroTren: String
    var localizador: String
    var anden: String
    var urlReserva: String
}

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

struct ItemChecklist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var texto: String
    var completado: Bool
    var asignadoA: String
}

struct ActividadDia: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var diaIndex: Int
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
    var tieneTrenes: Bool = false
    var esSorpresa: Bool
    var pistaSorpresa: String
    var diasRevelarSorpresaAntes: Int = 0
    var recuerdo: String
    var momentoFavorito: String = ""
    var valoracion: ValoracionViaje = ValoracionViaje()
    var alojamiento: AlojamientoInfo = AlojamientoInfo()
    var gastos: [GastoViaje] = []
    var retosFoto: [RetoFotografico] = []
    var documentos: [DocumentoBoveda] = []
    var vuelos: [Vuelo]
    var trenes: [TrenViaje] = []
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
        tieneTrenes: Bool = false,
        esSorpresa: Bool,
        pistaSorpresa: String,
        diasRevelarSorpresaAntes: Int = 0,
        recuerdo: String,
        momentoFavorito: String = "",
        valoracion: ValoracionViaje = ValoracionViaje(),
        alojamiento: AlojamientoInfo = AlojamientoInfo(),
        gastos: [GastoViaje] = [],
        retosFoto: [RetoFotografico] = [],
        documentos: [DocumentoBoveda] = [],
        vuelos: [Vuelo],
        trenes: [TrenViaje] = [],
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
        self.tieneTrenes = tieneTrenes
        self.esSorpresa = esSorpresa
        self.pistaSorpresa = pistaSorpresa
        self.diasRevelarSorpresaAntes = max(0, diasRevelarSorpresaAntes)
        self.recuerdo = recuerdo
        self.momentoFavorito = momentoFavorito
        self.valoracion = valoracion
        self.alojamiento = alojamiento
        self.gastos = gastos
        self.retosFoto = retosFoto
        self.documentos = documentos
        self.vuelos = vuelos
        self.trenes = trenes
        self.checklist = checklist
        self.itinerario = itinerario
        self.ideas = ideas
    }
    
    enum CodingKeys: String, CodingKey {
        case id, titulo, destino, fechaInicio, fechaFin, icono, tieneVuelos, tieneTrenes, esSorpresa, pistaSorpresa
        case diasRevelarSorpresaAntes, recuerdo, momentoFavorito, valoracion, alojamiento, gastos
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
        alojamiento = try c.decodeIfPresent(AlojamientoInfo.self, forKey: .alojamiento) ?? AlojamientoInfo()
        gastos = try c.decodeIfPresent([GastoViaje].self, forKey: .gastos) ?? []
        retosFoto = try c.decodeIfPresent([RetoFotografico].self, forKey: .retosFoto) ?? []
        documentos = try c.decodeIfPresent([DocumentoBoveda].self, forKey: .documentos) ?? []
        checklist = try c.decodeIfPresent([ItemChecklist].self, forKey: .checklist) ?? []
        itinerario = try c.decodeIfPresent([ActividadDia].self, forKey: .itinerario) ?? []
        ideas = try c.decodeIfPresent([String].self, forKey: .ideas) ?? []
    }
}

// ============================================================================
// 2. SERVICIOS EXTERNOS
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
            "AF": ("Air France", "https://www.airfrance.es", "Terminal 2"),
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

struct PrevisionDia: Identifiable {
    let id = UUID()
    let fecha: String
    let icono: String
    let tempMax: Int
    let tempMin: Int
    let descripcion: String
}

enum ServicioClima {
    static func obtenerPrevision(destino: String, fechaInicio: Date) async -> [PrevisionDia] {
        let limpio = destino.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return [] }
        
        var coordenada: CLLocationCoordinate2D? = nil
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.geocodeAddressString(limpio),
           let loc = placemarks.first?.location {
            coordenada = loc.coordinate
        }
        
        guard let coord = coordenada else { return [] }
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=5"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let times = daily["time"] as? [String],
                  let codes = daily["weathercode"] as? [Int],
                  let maxTemps = daily["temperature_2m_max"] as? [Double],
                  let minTemps = daily["temperature_2m_min"] as? [Double] else {
                return []
            }
            
            let count = min(times.count, min(codes.count, min(maxTemps.count, minTemps.count)))
            var resultados: [PrevisionDia] = []
            let formatterEntrada = DateFormatter()
            formatterEntrada.dateFormat = "yyyy-MM-dd"
            let formatterSalida = DateFormatter()
            formatterSalida.locale = Locale(identifier: "es_ES")
            formatterSalida.dateFormat = "EEE d"
            
            for i in 0..<count {
                let etiquetaFecha: String
                if let fechaObj = formatterEntrada.date(from: times[i]) {
                    etiquetaFecha = formatterSalida.string(from: fechaObj).capitalized
                } else {
                    etiquetaFecha = times[i]
                }
                let info = infoCodigoClima(codes[i])
                resultados.append(
                    PrevisionDia(
                        fecha: etiquetaFecha,
                        icono: info.icono,
                        tempMax: Int(round(maxTemps[i])),
                        tempMin: Int(round(minTemps[i])),
                        descripcion: info.texto
                    )
                )
            }
            return resultados
        } catch {
            return []
        }
    }
    
    private static func infoCodigoClima(_ code: Int) -> (icono: String, texto: String) {
        switch code {
        case 0: return ("☀️", "Despejado")
        case 1, 2: return ("🌤️", "Poco nuboso")
        case 3: return ("☁️", "Nublado")
        case 45, 48: return ("🌫️", "Niebla")
        case 51, 53, 55, 61, 63, 65: return ("🌧️", "Lluvia")
        case 71, 73, 75, 77: return ("❄️", "Nieve")
        case 80, 81, 82: return ("🌦️", "Chubascos")
        case 95, 96, 99: return ("⛈️", "Tormenta")
        default: return ("🌡️", "Variable")
        }
    }
}

enum ServicioDivisas {
    struct MonedaItem: Identifiable, Hashable {
        var id: String { codigo }
        let codigo: String
        let nombre: String
        let region: String
    }
    
    static let monedasDisponibles: [MonedaItem] = [
        MonedaItem(codigo: "EUR", nombre: "Euro (€)", region: "Europa"),
        MonedaItem(codigo: "GBP", nombre: "Libra esterlina (GBP)", region: "Europa"),
        MonedaItem(codigo: "CHF", nombre: "Franco suizo (CHF)", region: "Europa"),
        MonedaItem(codigo: "CZK", nombre: "Corona checa (CZK)", region: "Europa"),
        MonedaItem(codigo: "PLN", nombre: "Zloty polaco (PLN)", region: "Europa"),
        MonedaItem(codigo: "HUF", nombre: "Forinto húngaro (HUF)", region: "Europa"),
        MonedaItem(codigo: "SEK", nombre: "Corona sueca (SEK)", region: "Europa"),
        MonedaItem(codigo: "NOK", nombre: "Corona noruega (NOK)", region: "Europa"),
        MonedaItem(codigo: "DKK", nombre: "Corona danesa (DKK)", region: "Europa"),
        MonedaItem(codigo: "ISK", nombre: "Corona islandesa (ISK)", region: "Europa"),
        MonedaItem(codigo: "RON", nombre: "Leu rumano (RON)", region: "Europa"),
        MonedaItem(codigo: "BGN", nombre: "Lev búlgaro (BGN)", region: "Europa"),
        MonedaItem(codigo: "RSD", nombre: "Dinar serbio (RSD)", region: "Europa"),
        MonedaItem(codigo: "ALL", nombre: "Lek albanés (ALL)", region: "Europa"),
        MonedaItem(codigo: "TRY", nombre: "Lira turca (TRY)", region: "Europa"),
        MonedaItem(codigo: "USD", nombre: "Dólar estadounidense (USD)", region: "Norteamérica"),
        MonedaItem(codigo: "CAD", nombre: "Dólar canadiense (CAD)", region: "Norteamérica"),
        MonedaItem(codigo: "MXN", nombre: "Peso mexicano (MXN)", region: "Norteamérica"),
        MonedaItem(codigo: "ARS", nombre: "Peso argentino (ARS)", region: "Latinoamérica"),
        MonedaItem(codigo: "BRL", nombre: "Real brasileño (BRL)", region: "Latinoamérica"),
        MonedaItem(codigo: "CLP", nombre: "Peso chileno (CLP)", region: "Latinoamérica"),
        MonedaItem(codigo: "COP", nombre: "Peso colombiano (COP)", region: "Latinoamérica"),
        MonedaItem(codigo: "PEN", nombre: "Sol peruano (PEN)", region: "Latinoamérica"),
        MonedaItem(codigo: "UYU", nombre: "Peso uruguayo (UYU)", region: "Latinoamérica"),
        MonedaItem(codigo: "CRC", nombre: "Colón costarricense (CRC)", region: "Latinoamérica"),
        MonedaItem(codigo: "DOP", nombre: "Peso dominicano (DOP)", region: "Latinoamérica"),
        MonedaItem(codigo: "GTQ", nombre: "Quetzal guatemalteco (GTQ)", region: "Latinoamérica"),
        MonedaItem(codigo: "PAB", nombre: "Balboa panameño (PAB)", region: "Latinoamérica"),
        MonedaItem(codigo: "PYG", nombre: "Guaraní paraguayo (PYG)", region: "Latinoamérica"),
        MonedaItem(codigo: "BOB", nombre: "Boliviano (BOB)", region: "Latinoamérica"),
        MonedaItem(codigo: "JPY", nombre: "Yen japonés (JPY)", region: "Asia"),
        MonedaItem(codigo: "KRW", nombre: "Won surcoreano (KRW)", region: "Asia"),
        MonedaItem(codigo: "CNY", nombre: "Yuan chino (CNY)", region: "Asia"),
        MonedaItem(codigo: "HKD", nombre: "Dólar de Hong Kong (HKD)", region: "Asia"),
        MonedaItem(codigo: "TWD", nombre: "Dólar taiwanés (TWD)", region: "Asia"),
        MonedaItem(codigo: "THB", nombre: "Baht tailandés (THB)", region: "Asia"),
        MonedaItem(codigo: "VND", nombre: "Dong vietnamita (VND)", region: "Asia"),
        MonedaItem(codigo: "IDR", nombre: "Rupia indonesia (IDR)", region: "Asia"),
        MonedaItem(codigo: "SGD", nombre: "Dólar de Singapur (SGD)", region: "Asia"),
        MonedaItem(codigo: "MYR", nombre: "Ringgit malayo (MYR)", region: "Asia"),
        MonedaItem(codigo: "PHP", nombre: "Peso filipino (PHP)", region: "Asia"),
        MonedaItem(codigo: "INR", nombre: "Rupia india (INR)", region: "Asia"),
        MonedaItem(codigo: "AED", nombre: "Dírham EAU (AED)", region: "Asia"),
        MonedaItem(codigo: "QAR", nombre: "Riyal catarí (QAR)", region: "Asia"),
        MonedaItem(codigo: "SAR", nombre: "Riyal saudí (SAR)", region: "Asia"),
        MonedaItem(codigo: "ILS", nombre: "Nuevo séquel israelí (ILS)", region: "Asia"),
        MonedaItem(codigo: "JOD", nombre: "Dinar jordano (JOD)", region: "Asia"),
        MonedaItem(codigo: "MAD", nombre: "Dírham marroquí (MAD)", region: "Otros")
    ]
    
    static func tasaAEuros(desde moneda: String) async -> Double {
        let code = moneda.uppercased()
        if code == "EUR" { return 1.0 }
        
        if let url = URL(string: "https://open.er-api.com/v6/latest/\(code)") {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let rates = json["rates"] as? [String: Any],
                   let eurRate = rates["EUR"] as? Double, eurRate > 0 {
                    return eurRate
                }
            } catch {
                // Continuar
            }
        }
        
        let respaldo: [String: Double] = [
            "GBP": 1.19, "CHF": 1.06, "CZK": 0.0398, "PLN": 0.234, "HUF": 0.00245,
            "SEK": 0.087, "NOK": 0.085, "DKK": 0.134, "ISK": 0.0067, "RON": 0.20,
            "BGN": 0.511, "RSD": 0.0085, "ALL": 0.010, "TRY": 0.026,
            "USD": 0.92, "CAD": 0.66, "MXN": 0.046,
            "ARS": 0.0009, "BRL": 0.16, "CLP": 0.00095, "COP": 0.00021, "PEN": 0.245,
            "UYU": 0.022, "CRC": 0.0018, "DOP": 0.015, "GTQ": 0.119, "PAB": 0.92,
            "PYG": 0.00012, "BOB": 0.133,
            "JPY": 0.0061, "KRW": 0.00066, "CNY": 0.127, "HKD": 0.118, "TWD": 0.028,
            "THB": 0.027, "VND": 0.000036, "IDR": 0.000058, "SGD": 0.69, "MYR": 0.21,
            "PHP": 0.016, "INR": 0.011, "AED": 0.25, "QAR": 0.252, "SAR": 0.245,
            "ILS": 0.25, "JOD": 1.30, "MAD": 0.093
        ]
        return respaldo[code] ?? 1.0
    }
    
    static func urlGoogleFinanzas(cantidad: Double, desde moneda: String) -> URL? {
        let q = "\(cantidad) \(moneda) to EUR".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=\(q)")
    }
}

enum UtilidadImagen {
    static func comprimirParaNube(_ image: UIImage, maxLado: CGFloat = 850, calidad: CGFloat = 0.62) -> String? {
        let size = image.size
        let ratio = min(maxLado / max(size.width, 1), maxLado / max(size.height, 1))
        let targetSize = ratio >= 1 ? size : CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let redimensionada = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return redimensionada.jpegData(compressionQuality: calidad)?.base64EncodedString()
    }
}

enum GestorNotificaciones {
    static func solicitarPermiso() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    static func notificarCambioNotasIdeas(escapada: Escapada, detalle: String) {
        let content = UNMutableNotificationContent()
        content.title = "💡 Nuevas notas e ideas · \(escapada.titulo)"
        content.body = detalle.isEmpty ? "Se han actualizado las notas rápidas e ideas de «\(escapada.titulo)»." : detalle
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "notas_ideas_\(escapada.id.uuidString)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    static func programarParaEscapada(_ escapada: Escapada) {
        let center = UNUserNotificationCenter.current()
        let prefijoId = escapada.id.uuidString
        
        center.getPendingNotificationRequests { requests in
            let idsAnteriores = requests.map(\.identifier).filter { $0.hasPrefix(prefijoId) }
            center.removePendingNotificationRequests(withIdentifiers: idsAnteriores)
            
            if escapada.esSorpresa && !escapada.sorpresaDesbloqueada {
                let fechaAviso = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: escapada.fechaRevelacionSorpresa) ?? escapada.fechaRevelacionSorpresa
                if fechaAviso > Date() {
                    let content = UNMutableNotificationContent()
                    content.title = "🎁 ¡Se desvela la sorpresa!"
                    content.body = "Ya puedes descubrir el destino de «\(escapada.titulo)» (\(escapada.destino))."
                    content.sound = .default
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fechaAviso)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(identifier: "\(prefijoId)_sorpresa", content: content, trigger: trigger))
                }
            }
            
            for vuelo in escapada.vuelos {
                if let aviso24h = Calendar.current.date(byAdding: .hour, value: -24, to: vuelo.fechaHoraSalida),
                   aviso24h > Date() {
                    let content = UNMutableNotificationContent()
                    content.title = "✈️ Check-in abierto (\(vuelo.origen) → \(vuelo.destino))"
                    content.body = "Vuelo \(vuelo.numeroVuelo) mañana. Localizador: \(vuelo.localizador)."
                    content.sound = .default
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: aviso24h)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(identifier: "\(prefijoId)_vuelo_\(vuelo.id.uuidString)", content: content, trigger: trigger))
                }
            }
            
            if let avisoChecklist = Calendar.current.date(byAdding: .day, value: -2, to: escapada.fechaInicio),
               let avisoHora = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: avisoChecklist),
               avisoHora > Date() {
                let pendientes = escapada.checklist.filter { !$0.completado }.count
                if pendientes > 0 {
                    let content = UNMutableNotificationContent()
                    content.title = "🧳 ¡Faltan 2 días para \(escapada.titulo)!"
                    content.body = "Os quedan \(pendientes) cosas pendientes en vuestra checklist."
                    content.sound = .default
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: avisoHora)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(identifier: "\(prefijoId)_checklist", content: content, trigger: trigger))
                }
            }
        }
    }
}

private func iconoCategoriaGasto(_ categoria: String) -> String {
    switch categoria {
    case "Comida": return "🍽️"
    case "Transporte": return "🚆"
    case "Alojamiento": return "🏨"
    case "Entradas": return "🎟️"
    default: return "💳"
    }
}

// ============================================================================
// 3. GESTOR DE ESTADO Y SINCRONIZACIÓN EN TIEMPO REAL CON FIRESTORE
// ============================================================================

@MainActor
class EscapadasStore: ObservableObject {
    @Published var escapadas: [Escapada] = []
    @Published var wishlist: [DeseoViaje] = []
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
    private let localBackupKey = "nuestras_escapadas_backup_v3"
    private let localWishlistKey = "nuestras_escapadas_wishlist_v1"
    private var primeraCargaSala = true
    
    init() {
        let guardado = UserDefaults.standard.string(forKey: "codigo_pareja_ios") ?? "VIAJE-2026"
        self.codigoPareja = guardado
        GestorNotificaciones.solicitarPermiso()
        cargarCopiaLocal()
        configurarFirebase()
    }
    
    deinit {
        listener?.remove()
        wishlistListener?.remove()
    }
    
    private func configurarFirebase() {
        let rutaPlist = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
            ?? Bundle.main.urls(forResourcesWithExtension: "plist", subdirectory: nil)?.first(where: { $0.lastPathComponent == "GoogleService-Info.plist" })?.path

        guard rutaPlist != nil else {
            estadoNube = "Modo local (falta GoogleService-Info.plist)"
            firebaseActivo = false
            if escapadas.isEmpty { cargarEjemplosIniciales(subirANube: false) }
            if wishlist.isEmpty { cargarWishlistInicial(subirANube: false) }
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
                
                if !self.primeraCargaSala {
                    for escRemota in remotas {
                        if let escAnterior = self.escapadas.first(where: { $0.id == escRemota.id }),
                           escAnterior.ideas != escRemota.ideas {
                            let nuevas = escRemota.ideas.filter { !escAnterior.ideas.contains($0) }
                            let textoAviso = nuevas.first.map { "Nuevo en ideas: \($0)" } ?? "Cambio en notas rápidas e ideas"
                            GestorNotificaciones.notificarCambioNotasIdeas(escapada: escRemota, detalle: textoAviso)
                        }
                    }
                }
                
                self.primeraCargaSala = false
                self.escapadas = remotas
                self.guardarCopiaLocal()
                for esc in remotas {
                    GestorNotificaciones.programarParaEscapada(esc)
                }
            }
        }
        
        let colWishlist = db.collection("parejas").document(limpio).collection("wishlist")
        wishlistListener = colWishlist.addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor [weak self] in
                guard let self = self, let docs = snapshot?.documents else { return }
                let remotos: [DeseoViaje] = docs.compactMap { try? $0.data(as: DeseoViaje.self) }
                if remotos.isEmpty && self.wishlist.isEmpty {
                    self.cargarWishlistInicial(subirANube: true)
                } else {
                    self.wishlist = remotos.sorted { $0.fechaAgregado > $1.fechaAgregado }
                    self.guardarCopiaLocal()
                }
            }
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
        GestorNotificaciones.programarParaEscapada(nueva)
    }
    
    func actualizarEscapada(_ editada: Escapada) {
        if let idx = escapadas.firstIndex(where: { $0.id == editada.id }) {
            escapadas[idx] = editada
        } else {
            escapadas.append(editada)
        }
        guardarCopiaLocal()
        guardarEnFirestore(editada)
        GestorNotificaciones.programarParaEscapada(editada)
    }
    
    func eliminarEscapada(_ escapada: Escapada) {
        escapadas.removeAll { $0.id == escapada.id }
        guardarCopiaLocal()
        eliminarDeFirestore(escapada)
    }
    
    func agregarDeseo(_ deseo: DeseoViaje) {
        wishlist.insert(deseo, at: 0)
        guardarCopiaLocal()
        guard let db = db else { return }
        try? db.collection("parejas")
            .document(codigoPareja)
            .collection("wishlist")
            .document(deseo.id.uuidString)
            .setData(from: deseo, merge: false)
    }
    
    func eliminarDeseo(_ deseo: DeseoViaje) {
        wishlist.removeAll { $0.id == deseo.id }
        guardarCopiaLocal()
        guard let db = db else { return }
        db.collection("parejas")
            .document(codigoPareja)
            .collection("wishlist")
            .document(deseo.id.uuidString)
            .delete()
    }
    
    private func cargarWishlistInicial(subirANube: Bool) {
        let iniciales = [
            DeseoViaje(destino: "Kioto y Tokio en primavera", nota: "Ver los cerezos en flor y probar ramen auténtico", icono: "🌸", agregadoPor: "Ambos"),
            DeseoViaje(destino: "Costa Amalfitana en coche", nota: "Positano, Ravello y helados frente al mar", icono: "🍋", agregadoPor: "Ambos")
        ]
        wishlist = iniciales
        guardarCopiaLocal()
        if subirANube, let db = db {
            for d in iniciales {
                try? db.collection("parejas").document(codigoPareja).collection("wishlist").document(d.id.uuidString).setData(from: d, merge: false)
            }
        }
    }
    
    private func guardarEnFirestore(_ escapada: Escapada) {
        guard let db = db else { return }
        do {
            try db.collection("parejas")
                .document(codigoPareja)
                .collection("escapadas")
                .document(escapada.id.uuidString)
                .setData(from: escapada, merge: false)
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
            let wData = try JSONEncoder().encode(wishlist)
            UserDefaults.standard.set(wData, forKey: localWishlistKey)
        } catch {
            // Ignorar
        }
    }
    
    private func cargarCopiaLocal() {
        if let data = UserDefaults.standard.data(forKey: localBackupKey),
           let dec = try? JSONDecoder().decode([Escapada].self, from: data) {
            escapadas = dec
        }
        if let wData = UserDefaults.standard.data(forKey: localWishlistKey),
           let wDec = try? JSONDecoder().decode([DeseoViaje].self, from: wData) {
            wishlist = wDec
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
                esSorpresa: false,
                pistaSorpresa: "",
                diasRevelarSorpresaAntes: 0,
                recuerdo: "",
                retosFoto: [
                    RetoFotografico(titulo: "Selfie brindando con algo típico"),
                    RetoFotografico(titulo: "Foto en el puente o mirador más famoso"),
                    RetoFotografico(titulo: "El plato o dulce más curioso que probemos")
                ],
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
                GestorNotificaciones.programarParaEscapada(esc)
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
    @State private var delegadoNotificaciones = DelegadoNotificacionesPopUp()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = delegadoNotificaciones
                }
        }
    }
}

final class DelegadoNotificacionesPopUp: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

// ============================================================================
// 5. PESTAÑAS PRINCIPALES
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
                WishlistView()
                    .navigationTitle("Algún día iremos")
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
// 6. PRÓXIMAS ESCAPADAS Y CUENTA ATRÁS
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
                    Text(oculto ? "🔒 Destino oculto hasta el \(escapada.fechaRevelacionSorpresa.formatted(date: .abbreviated, time: .omitted))" : "📍 \(escapada.destino)")
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
// 7. DETALLE DE ESCAPADA
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
    @State private var nuevoRetoTexto = ""
    
    @State private var mostrandoAgregarVuelo = false
    @State private var mostrandoAgregarTren = false
    @State private var mostrandoEditarAlojamiento = false
    @State private var mostrandoAgregarGasto = false
    @State private var mostrandoAgregarDocumento = false
    @State private var mostrandoRuleta = false
    @State private var documentoSeleccionado: DocumentoBoveda? = nil
    @State private var retoParaFoto: RetoFotografico? = nil
    @State private var itemPickerReto: PhotosPickerItem? = nil
    @State private var retoConFotoEnVisor: RetoFotografico? = nil
    @State private var codigoAlojamientoCopiado = false
    @State private var previsionClima: [PrevisionDia] = []
    @State private var cargandoClima = false
    
    private var escapadaActual: Escapada? {
        store.escapadas.first(where: { $0.id == escapadaId })
    }
    
    var body: some View {
        Group {
            if let escapada = escapadaActual {
                contenidoDetalle(escapada: escapada)
            } else {
                ContentUnavailableView("Escapada no disponible", systemImage: "map")
            }
        }
        .sheet(isPresented: $mostrandoAgregarVuelo) {
            if let esc = escapadaActual {
                AgregarVueloSheet(escapada: esc)
            }
        }
        .sheet(isPresented: $mostrandoAgregarTren) {
            if let esc = escapadaActual {
                AgregarTrenSheet(escapada: esc)
            }
        }
        .sheet(isPresented: $mostrandoEditarAlojamiento) {
            if let esc = escapadaActual {
                EditarAlojamientoSheet(escapada: esc)
            }
        }
        .sheet(isPresented: $mostrandoAgregarGasto) {
            if let esc = escapadaActual {
                AgregarGastoSheet(escapada: esc)
            }
        }
        .sheet(isPresented: $mostrandoAgregarDocumento) {
            if let esc = escapadaActual {
                AgregarDocumentoSheet(escapada: esc)
            }
        }
        .sheet(isPresented: $mostrandoRuleta) {
            if let esc = escapadaActual {
                RuletaDecisionesSheet(escapada: esc)
            }
        }
        .sheet(item: $documentoSeleccionado) { doc in
            VisorDocumentoSheet(documento: doc)
        }
        .sheet(item: $retoConFotoEnVisor) { reto in
            VisorFotoRetoSheet(reto: reto)
        }
        .photosPicker(
            isPresented: Binding(
                get: { retoParaFoto != nil },
                set: { abierto in if !abierto { retoParaFoto = nil } }
            ),
            selection: $itemPickerReto,
            matching: .images
        )
        .onChange(of: itemPickerReto) { _, nuevoItem in
            guard let retoObjetivo = retoParaFoto,
                  let item = nuevoItem,
                  var copia = escapadaActual else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let original = UIImage(data: data),
                   let base64 = UtilidadImagen.comprimirParaNube(original) {
                    if let idx = copia.retosFoto.firstIndex(where: { $0.id == retoObjetivo.id }) {
                        copia.retosFoto[idx].fotoBase64 = base64
                        copia.retosFoto[idx].completado = true
                        store.actualizarEscapada(copia)
                    }
                }
                retoParaFoto = nil
                itemPickerReto = nil
            }
        }
    }
    
    @ViewBuilder
    private func contenidoDetalle(escapada: Escapada) -> some View {
        let sorpresaBloqueada = escapada.esSorpresa && !escapada.sorpresaDesbloqueada
        let totalesGasto = calcularTotalesGastos(escapada.gastos)
        
        List {
            Section {
                HStack(spacing: 14) {
                    Text(escapada.icono)
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(escapada.titulo)
                            .font(.title3.bold())
                        if sorpresaBloqueada {
                            Text("🔒 Destino secreto hasta el \(escapada.fechaRevelacionSorpresa.formatted(date: .abbreviated, time: .omitted))")
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
                    
                    Stepper(
                        escapada.diasRevelarSorpresaAntes == 0
                        ? "Revelar el mismo día del viaje"
                        : "Revelar \(escapada.diasRevelarSorpresaAntes) \(escapada.diasRevelarSorpresaAntes == 1 ? "día" : "días") antes",
                        value: Binding(
                            get: { escapada.diasRevelarSorpresaAntes },
                            set: { nuevosDias in
                                var copia = escapada
                                copia.diasRevelarSorpresaAntes = max(0, nuevosDias)
                                store.actualizarEscapada(copia)
                            }
                        ),
                        in: 0...30
                    )
                }
                
                Button {
                    mostrandoRuleta = true
                } label: {
                    HStack {
                        Text("🎲")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ruleta de decisiones en pareja")
                                .font(.subheadline.bold())
                            Text("¿No sabéis qué hacer o dónde cenar? Girad la ruleta")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if !sorpresaBloqueada && !escapada.yaVivida {
                Section {
                    if cargandoClima {
                        HStack {
                            ProgressView()
                            Text("Consultando el tiempo en \(escapada.destino)...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if previsionClima.isEmpty {
                        Text("Previsión meteorológica disponible para ciudades y destinos reconocidos.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(previsionClima) { dia in
                                    VStack(spacing: 4) {
                                        Text(dia.fecha)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Text(dia.icono)
                                            .font(.title2)
                                        Text("\(dia.tempMax)° / \(dia.tempMin)°")
                                            .font(.caption.bold().monospacedDigit())
                                        Text(dia.descripcion)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("🌤️ Previsión del tiempo en \(escapada.destino)")
                }
            }
            
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
                    
                    VStack(spacing: 8) {
                        TextField("Nombre del sitio o plan", text: $nuevoSitioNombre)
                        HStack {
                            TextField("URL opcional (https://...)", text: $nuevoSitioURL)
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
                                    ActividadDia(diaIndex: diaSeleccionado, nombreSitio: nombre, urlSitio: urlLimpia)
                                )
                                store.actualizarEscapada(copia)
                                nuevoSitioNombre = ""
                                nuevoSitioURL = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            .disabled(nuevoSitioNombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    let actividadesDelDia = escapada.itinerario.filter { $0.diaIndex == diaSeleccionado }
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
                } header: {
                    Text(escapada.totalDias > 1 ? "Itinerario por días (Día \(diaSeleccionado))" : "Plan del día y sitios")
                }
                
                if escapada.tieneVuelos || !escapada.vuelos.isEmpty {
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
                            mostrandoAgregarVuelo = true
                        } label: {
                            Label("Añadir vuelo", systemImage: "airplane.circle.fill")
                        }
                    } header: {
                        Text("Vuelos y billetes")
                    }
                }
                
                if escapada.tieneTrenes || !escapada.trenes.isEmpty {
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
                            mostrandoAgregarTren = true
                        } label: {
                            Label("Añadir tren", systemImage: "tram.fill")
                        }
                        
                        HStack(spacing: 8) {
                            if let urlRenfe = URL(string: "https://www.renfe.com") {
                                Link("Renfe", destination: urlRenfe)
                                    .font(.caption.bold())
                                    .buttonStyle(.bordered)
                            }
                            if let urlIryo = URL(string: "https://iryo.eu") {
                                Link("Iryo", destination: urlIryo)
                                    .font(.caption.bold())
                                    .buttonStyle(.bordered)
                            }
                            if let urlOuigo = URL(string: "https://www.ouigo.com/es") {
                                Link("Ouigo", destination: urlOuigo)
                                    .font(.caption.bold())
                                    .buttonStyle(.bordered)
                            }
                        }
                    } header: {
                        Text("🚆 Trenes (España)")
                    }
                }
                
                Section {
                    if escapada.alojamiento.tieneDatos {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(escapada.alojamiento.nombre.isEmpty ? "Alojamiento reservado" : escapada.alojamiento.nombre)
                                        .font(.headline)
                                    if !escapada.alojamiento.direccion.isEmpty {
                                        Text("📍 \(escapada.alojamiento.direccion)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button("Editar") {
                                    mostrandoEditarAlojamiento = true
                                }
                                .font(.caption.bold())
                            }
                            
                            HStack(spacing: 8) {
                                if !escapada.alojamiento.codigoReserva.isEmpty {
                                    Button {
                                        UIPasteboard.general.string = escapada.alojamiento.codigoReserva
                                        codigoAlojamientoCopiado = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            codigoAlojamientoCopiado = false
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text("Ref: \(escapada.alojamiento.codigoReserva)")
                                                .font(.caption.monospaced().bold())
                                            Image(systemName: codigoAlojamientoCopiado ? "checkmark" : "doc.on.doc")
                                                .font(.caption2)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                let queryMapa = (escapada.alojamiento.direccion.isEmpty ? "\(escapada.alojamiento.nombre) \(escapada.destino)" : escapada.alojamiento.direccion)
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
                    } else {
                        Button {
                            mostrandoEditarAlojamiento = true
                        } label: {
                            Label("Añadir hotel o apartamento", systemImage: "bed.double.fill")
                        }
                    }
                } header: {
                    Text("🏨 Alojamiento")
                }
            }
            
            Section {
                HStack {
                    TextField("Nuevo reto fotográfico...", text: $nuevoRetoTexto)
                    Button {
                        let texto = nuevoRetoTexto.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !texto.isEmpty else { return }
                        var copia = escapada
                        copia.retosFoto.append(RetoFotografico(titulo: texto))
                        store.actualizarEscapada(copia)
                        nuevoRetoTexto = ""
                    } label: {
                        Image(systemName: "camera.badge.plus")
                    }
                    .disabled(nuevoRetoTexto.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                ForEach(escapada.retosFoto) { reto in
                    HStack(spacing: 10) {
                        if let b64 = reto.fotoBase64,
                           let data = Data(base64Encoded: b64),
                           let uiImg = UIImage(data: data) {
                            Button {
                                retoConFotoEnVisor = reto
                            } label: {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 46, height: 46)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: reto.completado ? "checkmark.seal.fill" : "camera.circle")
                                .font(.title2)
                                .foregroundStyle(reto.completado ? .green : Color.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reto.titulo)
                                .font(.subheadline)
                                .strikethrough(reto.completado)
                            Text(reto.fotoBase64 != nil ? "📸 Foto guardada · Toca para ampliar" : "Añade la foto para completarlo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if reto.fotoBase64 != nil {
                                retoConFotoEnVisor = reto
                            } else {
                                var copia = escapada
                                if let idx = copia.retosFoto.firstIndex(where: { $0.id == reto.id }) {
                                    copia.retosFoto[idx].completado.toggle()
                                    store.actualizarEscapada(copia)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            retoParaFoto = reto
                        } label: {
                            Label(reto.fotoBase64 == nil ? "Foto" : "Cambiar", systemImage: "photo.badge.plus")
                                .font(.caption2.bold())
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .onDelete { offsets in
                    var copia = escapada
                    copia.retosFoto.remove(atOffsets: offsets)
                    store.actualizarEscapada(copia)
                }
            } header: {
                Text("📸 Retos fotográficos del viaje")
            }
            
            Section {
                VStack(spacing: 10) {
                    TextField("¿Qué hay que llevar o preparar?", text: $nuevoItemTexto)
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
                                ItemChecklist(texto: nuevoItemTexto.trimmingCharacters(in: .whitespaces), completado: false, asignadoA: nuevoItemAsignado)
                            )
                            store.actualizarEscapada(copia)
                            nuevoItemTexto = ""
                        } label: {
                            Label("Añadir", systemImage: "plus.circle.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                ForEach(escapada.checklist) { item in
                    HStack {
                        Image(systemName: item.completado ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.completado ? Color.accentColor : .secondary)
                        Text(item.texto)
                            .strikethrough(item.completado)
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
            
            Section {
                let totalGastos = totalesGasto.total
                let pagadoYo = totalesGasto.yo
                let pagadoTu = totalesGasto.tu
                let diferencia = pagadoYo - (totalGastos / 2.0)
                
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TOTAL DEL VIAJE (EN €)")
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
                        Text(String(format: "%.2f €", gasto.importe))
                            .font(.subheadline.bold().monospacedDigit())
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
                    Label("Añadir gasto (con conversor de divisa)", systemImage: "eurosign.arrow.circlepath")
                }
            } header: {
                Text("Gastos compartidos")
            }
            
            if escapada.yaVivida {
                Section {
                    SelectorEstrellasFila(titulo: "🏙️ La ciudad", puntuacion: Binding(
                        get: { escapada.valoracion.experienciaCiudad },
                        set: { v in
                            var copia = escapada
                            copia.valoracion.experienciaCiudad = v
                            store.actualizarEscapada(copia)
                        }
                    ))
                    SelectorEstrellasFila(titulo: "🏛️ Museos y cultura", puntuacion: Binding(
                        get: { escapada.valoracion.museosCultura },
                        set: { v in
                            var copia = escapada
                            copia.valoracion.museosCultura = v
                            store.actualizarEscapada(copia)
                        }
                    ))
                    SelectorEstrellasFila(titulo: "🍽️ La comida", puntuacion: Binding(
                        get: { escapada.valoracion.gastronomia },
                        set: { v in
                            var copia = escapada
                            copia.valoracion.gastronomia = v
                            store.actualizarEscapada(copia)
                        }
                    ))
                    SelectorEstrellasFila(titulo: "🏨 Alojamiento", puntuacion: Binding(
                        get: { escapada.valoracion.alojamientoDescanso },
                        set: { v in
                            var copia = escapada
                            copia.valoracion.alojamientoDescanso = v
                            store.actualizarEscapada(copia)
                        }
                    ))
                    SelectorEstrellasFila(titulo: "💕 Momentos juntos", puntuacion: Binding(
                        get: { escapada.valoracion.momentosJuntos },
                        set: { v in
                            var copia = escapada
                            copia.valoracion.momentosJuntos = v
                            store.actualizarEscapada(copia)
                        }
                    ))
                    
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
                        .frame(minHeight: 120)
                    }
                } header: {
                    Text("⭐ Puntuación y nuestro recuerdo")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    store.eliminarEscapada(escapada)
                    dismiss()
                } label: {
                    Label("Eliminar escapada", systemImage: "trash")
                }
            }
        }
        .navigationTitle(escapada.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(escapada.id.uuidString)-\(escapada.destino)") {
            guard !sorpresaBloqueada, !escapada.yaVivida else { return }
            cargandoClima = true
            previsionClima = await ServicioClima.obtenerPrevision(destino: escapada.destino, fechaInicio: escapada.fechaInicio)
            cargandoClima = false
        }
    }
    
    private func calcularTotalesGastos(_ gastos: [GastoViaje]) -> (total: Double, yo: Double, tu: Double) {
        var total = 0.0
        var yo = 0.0
        var tu = 0.0
        for g in gastos {
            total += g.importe
            if g.pagadoPor == "Yo" {
                yo += g.importe
            } else if g.pagadoPor == "Tú" {
                tu += g.importe
            }
        }
        return (total, yo, tu)
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

struct AgregarDocumentoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    
    @State private var titulo = ""
    @State private var tipo = "Entrada / QR"
    @State private var codigoOUrl = ""
    
    let tipos = ["Entrada / QR", "Reserva", "Seguro", "Otro"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Documento") {
                    TextField("Título", text: $titulo)
                    Picker("Tipo", selection: $tipo) {
                        ForEach(tipos, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                    TextField("Código o enlace", text: $codigoOUrl)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Añadir documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let doc = DocumentoBoveda(
                            titulo: titulo.trimmingCharacters(in: .whitespacesAndNewlines),
                            tipo: tipo,
                            codigoOUrl: codigoOUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        var copia = escapada
                        copia.documentos.append(doc)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct SelectorEstrellasFila: View {
    let titulo: String
    @Binding var puntuacion: Int
    
    var body: some View {
        HStack {
            Text(titulo)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { estrella in
                    Button {
                        puntuacion = (puntuacion == estrella) ? 0 : estrella
                    } label: {
                        Image(systemName: estrella <= puntuacion ? "star.fill" : "star")
                            .foregroundStyle(estrella <= puntuacion ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                
                Text("\(tren.operadora) · \(tren.numeroTren)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(tren.origen)
                        .font(.title3.bold())
                    Text(tren.fechaHoraSalida.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Image(systemName: "tram.fill")
                    .foregroundStyle(Color.accentColor)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(tren.destino)
                        .font(.title3.bold())
                    Text(tren.fechaHoraLlegada.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                }
            }
            
            HStack {
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

struct AgregarTrenSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    
    @State private var trayecto = "Ida"
    @State private var origen = ""
    @State private var destino = ""
    @State private var salida = Date()
    @State private var llegada = Date()
    @State private var operadora = "Renfe"
    @State private var numeroTren = ""
    @State private var localizador = ""
    @State private var anden = ""
    @State private var urlReserva = "https://www.renfe.com"
    
    let operadorasEspana = ["Renfe", "Iryo", "Ouigo", "Alvia / Avlo", "Otra"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Operadora de trenes (España)") {
                    Picker("Operadora", selection: $operadora) {
                        ForEach(operadorasEspana, id: \.self) { op in
                            Text(op).tag(op)
                        }
                    }
                    .onChange(of: operadora) { _, nuevaOp in
                        if nuevaOp == "Iryo" {
                            urlReserva = "https://iryo.eu"
                        } else if nuevaOp == "Ouigo" {
                            urlReserva = "https://www.ouigo.com/es"
                        } else if nuevaOp.contains("Renfe") || nuevaOp.contains("Alvia") {
                            urlReserva = "https://www.renfe.com"
                        }
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
                }
                
                Section("Trayecto y horario") {
                    Picker("Trayecto", selection: $trayecto) {
                        Text("Ida").tag("Ida")
                        Text("Vuelta").tag("Vuelta")
                    }
                    TextField("Estación origen (ej: Madrid Atocha)", text: $origen)
                    TextField("Estación destino (ej: Barcelona Sants)", text: $destino)
                    DatePicker("Salida", selection: $salida)
                    DatePicker("Llegada", selection: $llegada)
                }
                
                Section("Billete y localizador") {
                    TextField("Nº de tren (opcional)", text: $numeroTren)
                        .autocapitalization(.allCharacters)
                    TextField("Localizador / Billete", text: $localizador)
                        .autocapitalization(.allCharacters)
                    TextField("Andén (opcional)", text: $anden)
                    TextField("Enlace de reserva", text: $urlReserva)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Añadir tren")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                salida = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: escapada.fechaInicio) ?? escapada.fechaInicio
                llegada = Calendar.current.date(byAdding: .minute, value: 165, to: salida) ?? salida
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let nuevoTren = TrenViaje(
                            trayecto: trayecto,
                            origen: origen.trimmingCharacters(in: .whitespacesAndNewlines),
                            destino: destino.trimmingCharacters(in: .whitespacesAndNewlines),
                            fechaHoraSalida: salida,
                            fechaHoraLlegada: llegada,
                            operadora: operadora,
                            numeroTren: numeroTren.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            localizador: localizador.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "SIN-LOC" : localizador.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            anden: anden.trimmingCharacters(in: .whitespacesAndNewlines),
                            urlReserva: urlReserva.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        var copia = escapada
                        copia.tieneTrenes = true
                        copia.trenes.append(nuevoTren)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(origen.trimmingCharacters(in: .whitespaces).isEmpty || destino.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct VisorDocumentoSheet: View {
    @Environment(\.dismiss) var dismiss
    let documento: DocumentoBoveda
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(documento.tipo.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                
                Text(documento.titulo)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                
                if let b64 = documento.imagenBase64,
                   let data = Data(base64Encoded: b64),
                   let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 6)
                }
                
                if !documento.codigoOUrl.isEmpty {
                    if let url = URL(string: documento.codigoOUrl), documento.codigoOUrl.lowercased().hasPrefix("http") {
                        Link(destination: url) {
                            Label("Abrir enlace del documento", systemImage: "safari")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text(documento.codigoOUrl)
                            .font(.headline.monospaced())
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

struct VisorFotoRetoSheet: View {
    @Environment(\.dismiss) var dismiss
    let reto: RetoFotografico
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("📸 RETO COMPLETADO")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
                
                Text(reto.titulo)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                
                if let b64 = reto.fotoBase64,
                   let data = Data(base64Encoded: b64),
                   let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(radius: 8)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Foto del reto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

struct RuletaDecisionesSheet: View {
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    
    @State private var modo = "Planes del viaje"
    @State private var opcionesPersonalizadas: [String] = ["Cenar tapas locales", "Paseo nocturno", "Cafetería con encanto", "Elegir tú"]
    @State private var nuevaOpcion = ""
    @State private var resultadoElegido: String? = nil
    @State private var girando = false
    
    private var opcionesActuales: [String] {
        switch modo {
        case "Planes del viaje":
            let delViaje = escapada.itinerario.map(\.nombreSitio) + escapada.ideas
            return delViaje.isEmpty ? opcionesPersonalizadas : delViaje
        case "¿Quién decide?":
            return ["Decide Yo 🙋‍♂️", "Decide Tú 🙋‍♀️", "Piedra, papel o tijera ✌️"]
        default:
            return opcionesPersonalizadas
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Modo", selection: $modo) {
                    Text("Planes del viaje").tag("Planes del viaje")
                    Text("¿Quién decide?").tag("¿Quién decide?")
                    Text("Personalizada").tag("Personalizada")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(height: 170)
                    
                    VStack(spacing: 10) {
                        Text(girando ? "🎲 Girando..." : (resultadoElegido ?? "¿Listos para decidir?"))
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            girarRuleta()
                        } label: {
                            Label(girando ? "Eligiendo..." : "Girar ruleta", systemImage: "die.face.5.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(girando || opcionesActuales.isEmpty)
                    }
                }
                .padding(.horizontal)
                
                List {
                    if modo == "Personalizada" {
                        Section("Añadir opción") {
                            HStack {
                                TextField("Ej: Restaurante italiano", text: $nuevaOpcion)
                                Button("Añadir") {
                                    let limpio = nuevaOpcion.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !limpio.isEmpty else { return }
                                    opcionesPersonalizadas.append(limpio)
                                    nuevaOpcion = ""
                                }
                            }
                        }
                    }
                    
                    Section("Opciones en juego (\(opcionesActuales.count))") {
                        ForEach(Array(opcionesActuales.enumerated()), id: \.offset) { _, op in
                            Text("• \(op)")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding(.top)
            .navigationTitle("Ruleta en pareja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
    
    private func girarRuleta() {
        let lista = opcionesActuales
        guard !lista.isEmpty else { return }
        girando = true
        var pasos = 0
        Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { timer in
            pasos += 1
            resultadoElegido = lista.randomElement()
            if pasos >= 14 {
                timer.invalidate()
                girando = false
            }
        }
    }
}

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
    @State private var tieneVuelos = false
    @State private var tieneTrenes = false
    @State private var operadoraTren = "Renfe"
    @State private var origenTren = ""
    @State private var destinoTren = ""
    @State private var localizadorTren = ""
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
                    Toggle("🚆 ¿Este viaje incluye tren?", isOn: $tieneTrenes)
                    
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
                    Toggle("🎁 Modo plan sorpresa", isOn: $esSorpresa)
                    if esSorpresa {
                        TextField("Pista para tu pareja", text: $pista)
                        Stepper(
                            diasRevelarAntes == 0 ? "Revelar: el mismo día" : "Revelar: \(diasRevelarAntes) días antes",
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
                        var trenesIniciales: [TrenViaje] = []
                        if tieneTrenes && (!origenTren.isEmpty || !destinoTren.isEmpty || !localizadorTren.isEmpty) {
                            let salidaTren = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: fechaInicio) ?? fechaInicio
                            let llegadaTren = Calendar.current.date(byAdding: .minute, value: 165, to: salidaTren) ?? salidaTren
                            let urlTren: String
                            if operadoraTren == "Iryo" { urlTren = "https://iryo.eu" }
                            else if operadoraTren == "Ouigo" { urlTren = "https://www.ouigo.com/es" }
                            else { urlTren = "https://www.renfe.com" }
                            
                            trenesIniciales.append(
                                TrenViaje(
                                    trayecto: "Ida",
                                    origen: origenTren.isEmpty ? "Origen" : origenTren,
                                    destino: destinoTren.isEmpty ? destino : destinoTren,
                                    fechaHoraSalida: salidaTren,
                                    fechaHoraLlegada: llegadaTren,
                                    operadora: operadoraTren,
                                    numeroTren: "",
                                    localizador: localizadorTren.isEmpty ? "SIN-LOC" : localizadorTren.uppercased(),
                                    anden: "",
                                    urlReserva: urlTren
                                )
                            )
                        }
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
    @State private var buscandoEnWeb = false
    @State private var mensajeAutocompletado = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("1. Código de reserva o vuelo + hora") {
                    TextField("Código de reserva / localizador", text: $localizador)
                        .autocapitalization(.allCharacters)
                    TextField("Nº de vuelo (ej: IB3140)", text: $numeroVuelo)
                        .autocapitalization(.allCharacters)
                    Picker("Trayecto", selection: $trayecto) {
                        Text("Ida").tag("Ida")
                        Text("Vuelta").tag("Vuelta")
                        Text("Escala").tag("Escala")
                    }
                    DatePicker("Fecha y hora de salida", selection: $salida)
                    Button {
                        Task { await buscarYAutocompletar() }
                    } label: {
                        HStack {
                            if buscandoEnWeb { ProgressView() }
                            else { Image(systemName: "globe.europe.africa.fill") }
                            Text(buscandoEnWeb ? "Buscando..." : "Autocompletar ruta")
                                .font(.subheadline.bold())
                        }
                    }
                    if !mensajeAutocompletado.isEmpty {
                        Text(mensajeAutocompletado)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Section("2. Ruta y detalles") {
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
                        let vuelo = Vuelo(
                            trayecto: trayecto,
                            origen: origen.uppercased(),
                            destino: destino.uppercased(),
                            fechaHoraSalida: salida,
                            fechaHoraLlegada: llegada,
                            aerolinea: aerolinea.isEmpty ? "Aerolínea" : aerolinea,
                            numeroVuelo: numeroVuelo.uppercased(),
                            localizador: localizador.trimmingCharacters(in: .whitespaces).isEmpty ? "SIN-LOC" : localizador.uppercased(),
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
            llegada = Calendar.current.date(byAdding: .minute, value: res.duracionMin, to: salida) ?? salida
            mensajeAutocompletado = "✨ \(res.fuente): \(res.origen) → \(res.destino)"
        } else {
            mensajeAutocompletado = "Rellena origen y destino manualmente."
        }
    }
}

struct YaVividoView: View {
    @EnvironmentObject var store: EscapadasStore
    
    private func totalGastadoEscapada(_ esc: Escapada) -> Double {
        var total = 0.0
        for g in esc.gastos {
            total += g.importe
        }
        return total
    }
    
    var body: some View {
        List {
            if store.escapadasPasadas.isEmpty {
                ContentUnavailableView("Aún no hay recuerdos", systemImage: "photo.on.rectangle.angled")
            } else {
                Section("Recuerdos guardados") {
                    ForEach(store.escapadasPasadas) { esc in
                        let gastado = totalGastadoEscapada(esc)
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
                                Text(String(format: "💶 Total gastado: %.2f €", gastado))
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
                                if !esc.recuerdo.isEmpty {
                                    Text("\"\(esc.recuerdo)\"")
                                        .font(.caption)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Escapada.self) { esc in
            DetalleEscapadaView(escapadaId: esc.id)
        }
    }
}

struct StatMiniCard: View {
    let valor: String
    let etiqueta: String
    let icono: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icono)
                .font(.title3)
            Text(valor)
                .font(.headline.bold().monospacedDigit())
            Text(etiqueta)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WishlistView: View {
    @EnvironmentObject var store: EscapadasStore
    @State private var destinoNuevo = ""
    @State private var notaNueva = ""
    @State private var urlNueva = ""
    @State private var iconoSeleccionado = "✨"
    @State private var deseoAConvertir: DeseoViaje? = nil
    @State private var fechaInicioConvertir = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var fechaFinConvertir = Calendar.current.date(byAdding: .day, value: 33, to: Date()) ?? Date()
    
    let iconos = ["✨", "🏖️", "🏔️", "🌸", "🍋", "🍷", "🏙️", "🏕️"]
    
    var body: some View {
        List {
            Section("Añadir destino soñado") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(iconos, id: \.self) { em in
                            Text(em)
                                .font(.title2)
                                .padding(6)
                                .background(iconoSeleccionado == em ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { iconoSeleccionado = em }
                        }
                    }
                }
                
                TextField("Destino (ej: Islandia, Bali...)", text: $destinoNuevo)
                TextField("¿Qué os gustaría hacer allí?", text: $notaNueva)
                TextField("Enlace de referencia (opcional)", text: $urlNueva)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                Button {
                    let dest = destinoNuevo.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !dest.isEmpty else { return }
                    var urlLimpia = urlNueva.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !urlLimpia.isEmpty && !urlLimpia.hasPrefix("http") {
                        urlLimpia = "https://" + urlLimpia
                    }
                    let deseo = DeseoViaje(
                        destino: dest,
                        nota: notaNueva.trimmingCharacters(in: .whitespacesAndNewlines),
                        urlReferencia: urlLimpia,
                        icono: iconoSeleccionado
                    )
                    store.agregarDeseo(deseo)
                    destinoNuevo = ""
                    notaNueva = ""
                    urlNueva = ""
                } label: {
                    Label("Guardar en nuestra Wishlist", systemImage: "sparkles")
                        .font(.subheadline.bold())
                }
                .disabled(destinoNuevo.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            Section("Vuestros próximos sueños (\(store.wishlist.count))") {
                ForEach(store.wishlist) { deseo in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text(deseo.icono)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deseo.destino)
                                    .font(.headline)
                                if !deseo.nota.isEmpty {
                                    Text(deseo.nota)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        
                        HStack(spacing: 10) {
                            Button {
                                deseoAConvertir = deseo
                            } label: {
                                Label("Convertir en escapada", systemImage: "airplane.departure")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            
                            if let url = URL(string: deseo.urlReferencia), !deseo.urlReferencia.isEmpty {
                                Link(destination: url) {
                                    Label("Ver enlace", systemImage: "safari")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        store.eliminarDeseo(store.wishlist[idx])
                    }
                }
            }
        }
        .sheet(item: $deseoAConvertir) { deseo in
            NavigationStack {
                Form {
                    Section("Convertir «\(deseo.destino)» en viaje real") {
                        DatePicker("Fecha ida", selection: $fechaInicioConvertir, displayedComponents: .date)
                        DatePicker("Fecha vuelta", selection: $fechaFinConvertir, in: fechaInicioConvertir..., displayedComponents: .date)
                    }
                }
                .navigationTitle("Programar escapada")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { deseoAConvertir = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Crear escapada") {
                            let nueva = Escapada(
                                titulo: "Viaje a \(deseo.destino)",
                                destino: deseo.destino,
                                fechaInicio: fechaInicioConvertir,
                                fechaFin: fechaFinConvertir,
                                icono: deseo.icono,
                                tieneVuelos: true,
                                esSorpresa: false,
                                pistaSorpresa: "",
                                recuerdo: "",
                                vuelos: [],
                                checklist: [ItemChecklist(texto: "Revisar documentación", completado: false, asignadoA: "Ambos")],
                                ideas: deseo.nota.isEmpty ? [] : [deseo.nota]
                            )
                            store.agregarEscapada(nueva)
                            store.eliminarDeseo(deseo)
                            deseoAConvertir = nil
                        }
                    }
                }
            }
        }
    }
}

struct EditarAlojamientoSheet: View {
    @EnvironmentObject var store: EscapadasStore
    @Environment(\.dismiss) var dismiss
    let escapada: Escapada
    
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
            .navigationTitle("Alojamiento")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nombre = escapada.alojamiento.nombre
                direccion = escapada.alojamiento.direccion
                horaCheckIn = escapada.alojamiento.horaCheckIn
                horaCheckOut = escapada.alojamiento.horaCheckOut
                codigoReserva = escapada.alojamiento.codigoReserva
                urlReserva = escapada.alojamiento.urlReserva
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
                        var copia = escapada
                        copia.alojamiento = AlojamientoInfo(
                            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                            direccion: direccion.trimmingCharacters(in: .whitespacesAndNewlines),
                            horaCheckIn: horaCheckIn.trimmingCharacters(in: .whitespacesAndNewlines),
                            horaCheckOut: horaCheckOut.trimmingCharacters(in: .whitespacesAndNewlines),
                            codigoReserva: codigoReserva.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            urlReserva: urlLimpia
                        )
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
    @State private var monedaSeleccionada = "EUR"
    @State private var tasaAEuros: Double = 1.0
    @State private var cargandoTasa = false
    @State private var pagadoPor = "Yo"
    @State private var categoria = "Comida"
    
    let categorias = ["Comida", "Transporte", "Alojamiento", "Entradas", "Otros"]
    let regiones = ["Europa", "Norteamérica", "Latinoamérica", "Asia", "Otros"]
    
    private var importeNumerico: Double {
        let limpio = importeTexto.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(limpio) ?? 0
    }
    
    private var importeEnEuros: Double {
        monedaSeleccionada == "EUR" ? importeNumerico : (importeNumerico * tasaAEuros)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle y conversor de divisa") {
                    TextField("Concepto (ej: Cena en el centro)", text: $concepto)
                    
                    HStack {
                        TextField("Importe", text: $importeTexto)
                            .keyboardType(.decimalPad)
                        
                        Picker("Divisa", selection: $monedaSeleccionada) {
                            ForEach(ServicioDivisas.monedasDisponibles) { m in
                                Text("\(m.codigo) · \(m.region)").tag(m.codigo)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if monedaSeleccionada != "EUR" {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                if cargandoTasa {
                                    ProgressView()
                                    Text("Obteniendo cambio...")
                                        .font(.caption)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                    Text(String(format: "%.2f %@ ↔ %.2f €", importeNumerico, monedaSeleccionada, importeEnEuros))
                                        .font(.caption.bold().monospacedDigit())
                                }
                            }
                            Text(String(format: "1 %@ = %.4f € · 1 € ≈ %.2f %@", monedaSeleccionada, tasaAEuros, tasaAEuros > 0 ? (1.0 / tasaAEuros) : 0, monedaSeleccionada))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            if importeNumerico > 0, let googleUrl = ServicioDivisas.urlGoogleFinanzas(cantidad: importeNumerico, desde: monedaSeleccionada) {
                                Link(destination: googleUrl) {
                                    Label("Ver conversión exacta en Google", systemImage: "safari")
                                        .font(.caption2)
                                }
                            }
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
            .task(id: monedaSeleccionada) {
                if monedaSeleccionada == "EUR" {
                    tasaAEuros = 1.0
                } else {
                    cargandoTasa = true
                    tasaAEuros = await ServicioDivisas.tasaAEuros(desde: monedaSeleccionada)
                    cargandoTasa = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        guard importeEnEuros > 0 else { return }
                        let nuevoGasto = GastoViaje(
                            concepto: concepto.trimmingCharacters(in: .whitespacesAndNewlines),
                            importe: importeEnEuros,
                            importeOriginal: monedaSeleccionada == "EUR" ? nil : importeNumerico,
                            monedaOriginal: monedaSeleccionada == "EUR" ? nil : monedaSeleccionada,
                            pagadoPor: pagadoPor,
                            categoria: categoria
                        )
                        var copia = escapada
                        copia.gastos.append(nuevoGasto)
                        store.actualizarEscapada(copia)
                        dismiss()
                    }
                    .disabled(concepto.trimmingCharacters(in: .whitespaces).isEmpty || importeEnEuros <= 0)
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
                Section("Destinos desbloqueados") {
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