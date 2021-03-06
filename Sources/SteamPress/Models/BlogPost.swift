import Foundation
import Vapor
import Fluent

public class BlogPost: Model {

    static fileprivate let databaseTableName = "blogposts"
    public var id: Node?
    public var exists: Bool = false

    public var title: String
    public var contents: String
    public var author: Node?
    public var created: Date
    public var lastEdited: Date?
    public var slugUrl: String
    public var published: Bool

    init(title: String, contents: String, author: BlogUser, creationDate: Date, slugUrl: String, published: Bool) {
        self.id = nil
        self.title = title
        self.contents = contents
        self.author = author.id
        self.created = creationDate
        self.slugUrl = BlogPost.generateUniqueSlugUrl(from: slugUrl)
        self.lastEdited = nil
        self.published = published
    }

    required public init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        title = try node.extract("title")
        contents = try node.extract("contents")
        author = try node.extract("bloguser_id")
        slugUrl = try node.extract("slug_url")
        published = try node.extract("published")
        let createdTime: Double = try node.extract("created")
        let lastEditedTime: Double? = try? node.extract("last_edited")

        created = Date(timeIntervalSince1970: createdTime)

        if let lastEditedTime = lastEditedTime {
            lastEdited = Date(timeIntervalSince1970: lastEditedTime)
        }
    }
}

extension BlogPost: NodeRepresentable {
    public func makeNode(context: Context) throws -> Node {
        let createdTime = created.timeIntervalSince1970
        
        var node: [String: Node]  = [:]
        node["id"] = id
        node["title"] = title.makeNode()
        node["contents"] = contents.makeNode()
        node["bloguser_id"] = author?.makeNode()
        node["created"] = createdTime.makeNode()
        node["slug_url"] = slugUrl.makeNode()
        node["published"] = published.makeNode()

        if let lastEdited = lastEdited {
            node["last_edited"] = lastEdited.timeIntervalSince1970.makeNode()
        }
        
        if type(of: context) != BlogPostContext.self {
            return try node.makeNode()
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        let createdDate = dateFormatter.string(from: created)
        
        node["author_name"] = try getAuthor()?.name.makeNode()
        node["author_username"] = try getAuthor()?.username.makeNode()
        node["created_date"] = createdDate.makeNode()

        switch context {
        case BlogPostContext.shortSnippet:
            node["short_snippet"] = shortSnippet().makeNode()
            break
        case BlogPostContext.longSnippet:
            node["long_snippet"] = longSnippet().makeNode()

            let allTags = try tags()
            if allTags.count > 0 {
                node["tags"] = try allTags.makeNode()
            }
            break
        case BlogPostContext.all:
            let allTags = try tags()

            if allTags.count > 0 {
                node["tags"] = try allTags.makeNode()
            }
            
            let iso8601Formatter = DateFormatter()
            iso8601Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            iso8601Formatter.locale = Locale(identifier: "en_US_POSIX")
            iso8601Formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            node["created_date_iso8601"] = iso8601Formatter.string(from: created).makeNode()

            if let lastEdited = lastEdited {
                let lastEditedDate = dateFormatter.string(from: lastEdited)
                node["last_edited_date"] = lastEditedDate.makeNode()
                node["last_edited_date_iso8601"] = iso8601Formatter.string(from: lastEdited).makeNode()
            }
            node["short_snippet"] = shortSnippet().makeNode()
            node["long_snippet"] = longSnippet().makeNode()
        default: break
        }

        return try node.makeNode()
    }
}

extension BlogPost {

    public static func prepare(_ database: Database) throws {
        try database.create(databaseTableName) { posts in
            posts.id()
            posts.string("title")
            posts.custom("contents", type: "TEXT")
            posts.parent(BlogUser.self, optional: false)
            posts.double("created")
            posts.double("last_edited", optional: true)
            posts.string("slug_url", unique: true)
        }
    }

    public static func revert(_ database: Database) throws {
        try database.delete(databaseTableName)
    }
}

public enum BlogPostContext: Context {
    case all
    case shortSnippet
    case longSnippet
}

extension BlogPost {
    func getAuthor() throws -> BlogUser? {
        return try parent(author, nil, BlogUser.self).get()
    }
}

extension BlogPost {
    func tags() throws -> [BlogTag] {
        return try siblings().all()
    }
}

extension BlogPost {

    public func shortSnippet() -> String {
        return getLines(characterLimit: 150)
    }

    public func longSnippet() -> String {
        return getLines(characterLimit: 900)
    }

    private func getLines(characterLimit: Int) -> String {
        contents = contents.replacingOccurrences(of: "\r\n", with: "\n", options: .regularExpression)
        let lines = contents.components(separatedBy: "\n")
        var snippet = ""
        for line in lines {
            snippet += "\(line)\n"
            if snippet.count > characterLimit {
                return snippet
            }
        }
        return snippet
    }

}

extension BlogPost {
    public static func generateUniqueSlugUrl(from title: String) -> String {
        let alphanumericsWithHyphenAndSpace = CharacterSet(charactersIn: " -0123456789abcdefghijklmnopqrstuvwxyz")

        let slugUrl = title.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: alphanumericsWithHyphenAndSpace.inverted).joined()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            .replacingOccurrences(of: " ", with: "-", options: .regularExpression)

        var newSlugUrl = slugUrl
        var count = 2

        do {
            while try BlogPost.query().filter("slug_url", newSlugUrl).first() != nil {
              newSlugUrl = "\(slugUrl)-\(count)"
              count += 1
            }
        } catch {
            print("Error uniqueing the slug URL: \(error)")
            // Swallow error - this will propragate the error up to the DB driver which should fail if it is not unique
        }
        
        return newSlugUrl
    }
}
