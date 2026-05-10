import Vapor

struct PageMetadata: Content, Sendable {
    let page: Int
    let per: Int
    let total: Int
}

struct Page<T: Content & Sendable>: Content, Sendable {
    let items: [T]
    let metadata: PageMetadata
}

struct PageRequest: Content {
    var page: Int
    var per: Int

    init(page: Int = 1, per: Int = 20) {
        self.page = page
        self.per = per
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        page = (try? c.decode(Int.self, forKey: .page)) ?? 1
        per  = (try? c.decode(Int.self, forKey: .per))  ?? 20
    }

    enum CodingKeys: String, CodingKey { case page, per }

    var clampedPer: Int { min(max(per, 1), 100) }
    var offset: Int { (max(page, 1) - 1) * clampedPer }
}
