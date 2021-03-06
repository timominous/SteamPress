import XCTest
@testable import SteamPress
@testable import Vapor
import Fluent
import HTTP
import Foundation

class BlogControllerTests: XCTestCase {
    static var allTests = [
        ("testBlogIndexGetsPostsInReverseOrder", testBlogIndexGetsPostsInReverseOrder),
        ("testBlogIndexGetsAllTags", testBlogIndexGetsAllTags),
        ("testBlogIndexGetsDisqusNameIfSetInConfig", testBlogIndexGetsDisqusNameIfSetInConfig),
        ("testBlogPostRetrievedCorrectlyFromSlugUrl", testBlogPostRetrievedCorrectlyFromSlugUrl),
        ("testDisqusNamePassedToBlogPostIfSpecified", testDisqusNamePassedToBlogPostIfSpecified),
        ("testThatAccessingPathsRouteRedirectsToBlogIndex", testThatAccessingPathsRouteRedirectsToBlogIndex),
        ("testAuthorView", testAuthorView),
        ("testAuthorViewGetsDisqusNameIfSet", testAuthorViewGetsDisqusNameIfSet),
        ("testTagView", testTagView),
        ("testTagViewGetsDisquqNameIfSet", testTagViewGetsDisquqNameIfSet),
        ("testIndexPageGetsTwitterHandleIfSet", testIndexPageGetsTwitterHandleIfSet),
        ("testBlogPageGetsTwitterHandleIfSet", testBlogPageGetsTwitterHandleIfSet),
        ("testProfilePageGetsTwitterHandleIfSet", testProfilePageGetsTwitterHandleIfSet),
        ("testTagPageGetsTwitterHandleIfSet", testTagPageGetsTwitterHandleIfSet),
        ("testIndexPageGetsUri", testIndexPageGetsUri),
        ("testBlogPageGetsUri", testBlogPageGetsUri),
        ("testProfilePageGetsUri", testProfilePageGetsUri),
        ("testTagPageGetsUri", testTagPageGetsUri),
        ("testAllAuthorsPageGetsUri", testAllAuthorsPageGetsUri),
        ("testAllTagsPageGetsUri", testAllTagsPageGetsUri),
        ("testAllAuthorsPageGetsTwitterHandleIfSet", testAllAuthorsPageGetsTwitterHandleIfSet),
        ("testAllTagsPageGetsTwitterHandleIfSet", testAllTagsPageGetsTwitterHandleIfSet),
        ("testAllTagsPageGetsAllTags", testAllTagsPageGetsAllTags),
        ("testAllAuthorsPageGetAllAuthors", testAllAuthorsPageGetAllAuthors),
        ("testTagPageGetsOnlyPublishedPostsInDescendingOrder", testTagPageGetsOnlyPublishedPostsInDescendingOrder),
        ("testAuthorPageGetsOnlyPublishedPostsInDescendingOrder", testAuthorPageGetsOnlyPublishedPostsInDescendingOrder),
    ]

    private var drop: Droplet!
    private var viewFactory: CapturingViewFactory!
    private var post: BlogPost!
    private var user: BlogUser!
    private let blogIndexPath = "/"
    private let blogPostPath = "/posts/test-path/"
    private let tagPath = "/tags/tatooine/"
    private let authorPath = "/authors/luke/"
    private let allAuthorsPath = "/authors/"
    private let allTagsPath = "/tags/"
    private var blogPostRequest: Request!
    private var authorRequest: Request!
    private var tagRequest: Request!
    private var blogIndexRequest: Request!
    private var allTagsRequest: Request!
    private var allAuthorsRequest: Request!

    override func setUp() {
        blogPostRequest = try! Request(method: .get, uri: blogPostPath)
        authorRequest = try! Request(method: .get, uri: authorPath)
        tagRequest = try! Request(method: .get, uri: tagPath)
        blogIndexRequest = try! Request(method: .get, uri: blogIndexPath)
        allTagsRequest = try! Request(method: .get, uri: allTagsPath)
        allAuthorsRequest = try! Request(method: .get, uri: allAuthorsPath)
    }

    func setupDrop(config: Config? = nil, loginUser: Bool = false) throws {
        drop = Droplet(arguments: ["dummy/path/", "prepare"], config: config)
        drop.database = Database(MemoryDriver())

        let steampress = SteamPress.Provider(postsPerPage: 5)
        steampress.setup(drop)

        viewFactory = CapturingViewFactory()
        let pathCreator = BlogPathCreator(blogPath: nil)
        let blogController = BlogController(drop: drop, pathCreator: pathCreator, viewFactory: viewFactory, postsPerPage: 5, config: config ?? drop.config)
        blogController.addRoutes()

        let blogAdminController = BlogAdminController(drop: drop, pathCreator: pathCreator, viewFactory: viewFactory, postsPerPage: 5)
        blogAdminController.addRoutes()
        try drop.runCommands()

        if loginUser {
//            let userCredentials = BlogUserCredentials(username: "luke", password: "1234", name: "Luke")
//            user = try BlogUser(credentials: userCredentials)
        }
        else {
            user = TestDataBuilder.anyUser()
        }
        try user.save()
        post = BlogPost(title: "Test Path", contents: "A long time ago", author: user, creationDate: Date(), slugUrl: "test-path", published: true)
        try post.save()

        try BlogTag.addTag("tatooine", to: post)
    }

    func testBlogIndexGetsPostsInReverseOrder() throws {
        try setupDrop()

        var post2 = BlogPost(title: "A New Path", contents: "In a galaxy far, far, away", author: user, creationDate: Date(), slugUrl: "a-new-path", published: true)
        try post2.save()

        _ = try drop.respond(to: blogIndexRequest)

        XCTAssertEqual(viewFactory.paginatedPosts?.total, 2)
        XCTAssertEqual(viewFactory.paginatedPosts?.data?[0].title, "A New Path")
        XCTAssertEqual(viewFactory.paginatedPosts?.data?[1].title, "Test Path")

    }

    func testBlogIndexGetsAllTags() throws {
        try setupDrop()
        _ = try drop.respond(to: blogIndexRequest)

        XCTAssertEqual(viewFactory.blogIndexTags?.count, 1)
        XCTAssertEqual(viewFactory.blogIndexTags?.first?.name, "tatooine")
    }
    
    func testBlogIndexGetsAllAuthors() throws {
        try setupDrop()
        _ = try drop.respond(to: blogIndexRequest)
        
        XCTAssertEqual(viewFactory.blogIndexAuthors?.count, 1)
        XCTAssertEqual(viewFactory.blogIndexAuthors?.first?.name, "Luke")
    }

    func testBlogIndexGetsDisqusNameIfSetInConfig() throws {
        let expectedName = "steampress"
        let config = Config(try Node(node: [
            "disqus": try Node(node: [
                "disqusName": expectedName.makeNode()
                ])
            ]))
        try setupDrop(config: config)

        _ = try drop.respond(to: blogIndexRequest)

        XCTAssertEqual(expectedName, viewFactory.indexDisqusName)
    }

    func testBlogPostRetrievedCorrectlyFromSlugUrl() throws {
        try setupDrop()
        _ = try drop.respond(to: blogPostRequest)

        XCTAssertEqual(viewFactory.blogPost?.title, post.title)
        XCTAssertEqual(viewFactory.blogPost?.contents, post.contents)
        XCTAssertEqual(viewFactory.blogPostAuthor?.name, user.name)
        XCTAssertEqual(viewFactory.blogPostAuthor?.username, user.username)
    }

    func testDisqusNamePassedToBlogPostIfSpecified() throws {
        let expectedName = "steampress"
        let config = Config(try Node(node: [
            "disqus": try Node(node: [
                "disqusName": expectedName.makeNode()
                ])
        ]))
        try setupDrop(config: config)

        _ = try drop.respond(to: blogPostRequest)

        XCTAssertEqual(expectedName, viewFactory.disqusName)
    }

    func testThatAccessingPathsRouteRedirectsToBlogIndex() throws {
        try setupDrop()
        let request = try! Request(method: .get, uri: "/posts/")
        let response = try drop.respond(to: request)
        XCTAssertEqual(response.status, .movedPermanently)
        XCTAssertEqual(response.headers[HeaderKey.location], "/")
    }

//    func testUserPassedToBlogPostIfLoggedIn() throws {
//        try setupDrop(loginUser: true)
//        let requestData = "{\"username\": \"\(user.name)\", \"password\": \"1234\"}"
//        let loginRequest = try Request(method: .post, uri: "/admin/login/", body: requestData.makeBody())
//         _ = try drop.respond(to: loginRequest)
//    }

    func testAuthorView() throws {
        try setupDrop()
        _ = try drop.respond(to: authorRequest)

        XCTAssertEqual(viewFactory.author?.username, user.username)
        XCTAssertEqual(viewFactory.authorPosts?.total, 1)
        XCTAssertEqual(viewFactory.authorPosts?.data?[0].title, post.title)
        XCTAssertEqual(viewFactory.authorPosts?.data?[0].contents, post.contents)
        XCTAssertEqual(viewFactory.isMyProfile, false)
    }

    func testAuthorViewGetsDisqusNameIfSet() throws {
        let expectedName = "steampress"
        let config = Config(try Node(node: [
            "disqus": try Node(node: [
                "disqusName": expectedName.makeNode()
                ])
            ]))
        try setupDrop(config: config)

        _ = try drop.respond(to: authorRequest)

        XCTAssertEqual(expectedName, viewFactory.authorDisqusName)
    }

    func testTagView() throws {
        try setupDrop()
        _ = try drop.respond(to: tagRequest)

        XCTAssertEqual(viewFactory.tagPosts?.total, 1)
        XCTAssertEqual(viewFactory.tagPosts?.data?[0].title, post.title)
        XCTAssertEqual(viewFactory.tag?.name, "tatooine")
    }

    func testTagViewGetsDisquqNameIfSet() throws {
        let expectedName = "steampress"
        let config = Config(try Node(node: [
            "disqus": try Node(node: [
                "disqusName": expectedName.makeNode()
                ])
            ]))
        try setupDrop(config: config)

        _ = try drop.respond(to: tagRequest)

        XCTAssertEqual(expectedName, viewFactory.tagDisqusName)
    }
    
    func testIndexPageGetsTwitterHandleIfSet() throws {
        let expectedTwitterHandle = "brokenhandsio"
        let config = Config(try Node(node: [
            "twitter": try Node(node: [
                "siteHandle": expectedTwitterHandle.makeNode()
                ])
            ]))
        try setupDrop(config: config)
        
        _ = try drop.respond(to: blogIndexRequest)
        
        XCTAssertEqual(expectedTwitterHandle, viewFactory.blogIndexTwitterHandle)
    }
    
    func testBlogPageGetsTwitterHandleIfSet() throws {
        let expectedTwitterHandle = "brokenhandsio"
        let config = Config(try Node(node: [
            "twitter": try Node(node: [
                "siteHandle": expectedTwitterHandle.makeNode()
                ])
            ]))
        try setupDrop(config: config)
        
        _ = try drop.respond(to: blogPostRequest)
        
        XCTAssertEqual(expectedTwitterHandle, viewFactory.blogPostTwitterHandle)
    }
    
    func testProfilePageGetsTwitterHandleIfSet() throws {
        let expectedTwitterHandle = "brokenhandsio"
        let config = Config(try Node(node: [
            "twitter": try Node(node: [
                "siteHandle": expectedTwitterHandle.makeNode()
                ])
            ]))
        try setupDrop(config: config)
        
        _ = try drop.respond(to: authorRequest)
        
        XCTAssertEqual(expectedTwitterHandle, viewFactory.authorTwitterHandle)
    }
    
    func testTagPageGetsTwitterHandleIfSet() throws {
        let expectedTwitterHandle = "brokenhandsio"
        let config = Config(try Node(node: [
            "twitter": try Node(node: [
                "siteHandle": expectedTwitterHandle.makeNode()
                ])
            ]))
        try setupDrop(config: config)
        
        _ = try drop.respond(to: tagRequest)
        
        XCTAssertEqual(expectedTwitterHandle, viewFactory.tagTwitterHandle)
    }
    
    func testIndexPageGetsUri() throws {
        try setupDrop()
        
        _ = try drop.respond(to: blogIndexRequest)
        
        XCTAssertEqual(blogIndexPath, viewFactory.blogIndexURI?.description)
    }
    
    func testBlogPageGetsUri() throws {
        try setupDrop()
        
        _ = try drop.respond(to: blogPostRequest)
        
        XCTAssertEqual(blogPostPath, viewFactory.blogPostURI?.description)
    }
    
    func testProfilePageGetsUri() throws {
        try setupDrop()
        
        _ = try drop.respond(to: authorRequest)
        
        XCTAssertEqual(authorPath, viewFactory.authorURI?.description)
    }
    
    func testTagPageGetsUri() throws {
        try setupDrop()
        
        _ = try drop.respond(to: tagRequest)
        
        XCTAssertEqual(tagPath, viewFactory.tagURI?.description)
    }
    
    func testAllAuthorsPageGetsUri() throws {
        try setupDrop()
        
        _ = try drop.respond(to: allAuthorsRequest)
        
        XCTAssertEqual(allAuthorsPath, viewFactory.allAuthorsURI?.description)
    }
    
    func testAllTagsPageGetsUri() throws {
        try setupDrop()
        
        _ = try drop.respond(to: allTagsRequest)
        
        XCTAssertEqual(allTagsPath, viewFactory.allTagsURI?.description)
    }
    
    func testAllAuthorsPageGetsTwitterHandleIfSet() throws {
        let expectedTwitterHandle = "brokenhandsio"
        let config = Config(try Node(node: [
            "twitter": try Node(node: [
                "siteHandle": expectedTwitterHandle.makeNode()
                ])
            ]))
        try setupDrop(config: config)
        
        _ = try drop.respond(to: allAuthorsRequest)
        
        XCTAssertEqual(expectedTwitterHandle, viewFactory.allAuthorsTwitterHandle)
    }
    
    func testAllTagsPageGetsTwitterHandleIfSet() throws {
        let expectedTwitterHandle = "brokenhandsio"
        let config = Config(try Node(node: [
            "twitter": try Node(node: [
                "siteHandle": expectedTwitterHandle.makeNode()
                ])
            ]))
        try setupDrop(config: config)
        
        _ = try drop.respond(to: allTagsRequest)
        
        XCTAssertEqual(expectedTwitterHandle, viewFactory.allTagsTwitterHandle)
    }
    
    func testAllTagsPageGetsAllTags() throws {
        try setupDrop()
        _ = try drop.respond(to: allTagsRequest)
        
        XCTAssertEqual(1, viewFactory.allTagsPageTags?.count)
        XCTAssertEqual("tatooine", viewFactory.allTagsPageTags?.first?.name)
    }
    
    func testAllAuthorsPageGetAllAuthors() throws {
        try setupDrop()
        _ = try drop.respond(to: allAuthorsRequest)
        
        XCTAssertEqual(1, viewFactory.allAuthorsPageAuthors?.count)
        XCTAssertEqual("Luke", viewFactory.allAuthorsPageAuthors?.first?.name)
    }
    
    func testTagPageGetsOnlyPublishedPostsInDescendingOrder() throws {
        try setupDrop()
        var post2 = TestDataBuilder.anyPost(title: "A later post", author: self.user)
        try post2.save()
        var draftPost = TestDataBuilder.anyPost(author: self.user, published: false)
        try draftPost.save()
        try BlogTag.addTag("tatooine", to: post2)
        try BlogTag.addTag("tatooine", to: draftPost)
        _ = try drop.respond(to: tagRequest)
        
        XCTAssertEqual(2, viewFactory.tagPosts?.total)
        XCTAssertEqual(post2.title, viewFactory.tagPosts?.data?.first?.title)
    }
    
    func testAuthorPageGetsOnlyPublishedPostsInDescendingOrder() throws {
        try setupDrop()
        var post2 = TestDataBuilder.anyPost(title: "A later post", author: self.user)
        try post2.save()
        var draftPost = TestDataBuilder.anyPost(author: self.user, published: false)
        try draftPost.save()
        _ = try drop.respond(to: authorRequest)
        
        XCTAssertEqual(2, viewFactory.authorPosts?.total)
        XCTAssertEqual(post2.title, viewFactory.authorPosts?.data?[0].title)
    }
    
}

import URI
import Paginator
import Foundation

class CapturingViewFactory: ViewFactory {

    func createBlogPostView(uri: URI, errors: [String]?, title: String?, contents: String?, slugUrl: String?, tags: [Node]?, isEditing: Bool, postToEdit: BlogPost?, draft: Bool) throws -> View {
        return View(data: try "Test".makeBytes())
    }

    func createUserView(editing: Bool, errors: [String]?, name: String?, username: String?, passwordError: Bool?, confirmPasswordError: Bool?, resetPasswordRequired: Bool?, userId: Node?, profilePicture: String?, twitterHandle: String?, biography: String?, tagline: String?) throws -> View {
        return View(data: try "Test".makeBytes())
    }

    func createLoginView(loginWarning: Bool, errors: [String]?, username: String?, password: String?) throws -> View {
        return View(data: try "Test".makeBytes())
    }

    func createBlogAdminView(errors: [String]?) throws -> View {
        return View(data: try "Test".makeBytes())
    }

    func createResetPasswordView(errors: [String]?, passwordError: Bool?, confirmPasswordError: Bool?) throws -> View {
        return View(data: try "Test".makeBytes())
    }

    private(set) var author: BlogUser? = nil
    private(set) var isMyProfile: Bool? = nil
    private(set) var authorPosts: Paginator<BlogPost>? = nil
    private(set) var authorDisqusName: String? = nil
    private(set) var authorTwitterHandle: String? = nil
    private(set) var authorURI: URI? = nil
    func createProfileView(uri: URI, author: BlogUser, isMyProfile: Bool, paginatedPosts: Paginator<BlogPost>, loggedInUser: BlogUser?, disqusName: String?, siteTwitterHandle: String?) throws -> View {
        self.author = author
        self.isMyProfile = isMyProfile
        self.authorPosts = paginatedPosts
        self.authorDisqusName = disqusName
        self.authorTwitterHandle = siteTwitterHandle
        self.authorURI = uri
        return View(data: try "Test".makeBytes())
    }

    private(set) var blogPost: BlogPost? = nil
    private(set) var blogPostAuthor: BlogUser? = nil
    private(set) var disqusName: String? = nil
    private(set) var blogPostTwitterHandle: String? = nil
    private(set) var blogPostURI: URI? = nil
    func blogPostView(uri: URI, post: BlogPost, author: BlogUser, user: BlogUser?, disqusName: String?, siteTwitterHandle: String?) throws -> View {
        self.blogPost = post
        self.blogPostAuthor = author
        self.disqusName = disqusName
        self.blogPostTwitterHandle = siteTwitterHandle
        self.blogPostURI = uri
        return View(data: try "Test".makeBytes())
    }

    private(set) var tag: BlogTag? = nil
    private(set) var tagPosts: Paginator<BlogPost>? = nil
    private(set) var tagUser: BlogUser? = nil
    private(set) var tagDisqusName: String? = nil
    private(set) var tagTwitterHandle: String? = nil
    private(set) var tagURI: URI? = nil
    func tagView(uri: URI, tag: BlogTag, paginatedPosts: Paginator<BlogPost>, user: BlogUser?, disqusName: String?, siteTwitterHandle: String?) throws -> View {
        self.tag = tag
        self.tagPosts = paginatedPosts
        self.tagUser = user
        self.tagDisqusName = disqusName
        self.tagTwitterHandle = siteTwitterHandle
        self.tagURI = uri
        return View(data: try "Test".makeBytes())
    }

    private(set) var blogIndexTags: [BlogTag]? = nil
    private(set) var blogIndexAuthors: [BlogUser]? = nil
    private(set) var indexDisqusName: String? = nil
    private(set) var paginatedPosts: Paginator<BlogPost>? = nil
    private(set) var blogIndexTwitterHandle: String? = nil
    private(set) var blogIndexURI: URI? = nil
    func blogIndexView(uri: URI, paginatedPosts: Paginator<BlogPost>, tags: [BlogTag], authors: [BlogUser], loggedInUser: BlogUser?, disqusName: String?, siteTwitterHandle: String?) throws -> View {
        self.blogIndexTags = tags
        self.paginatedPosts = paginatedPosts
        self.indexDisqusName = disqusName
        self.blogIndexTwitterHandle = siteTwitterHandle
        self.blogIndexURI = uri
        self.blogIndexAuthors = authors
        return View(data: try "Test".makeBytes())
    }
    
    private(set) var allAuthorsTwitterHandle: String? = nil
    private(set) var allAuthorsURI: URI? = nil
    private(set) var allAuthorsPageAuthors: [BlogUser]? = nil
    func allAuthorsView(uri: URI, allAuthors: [BlogUser], user: BlogUser?, siteTwitterHandle: String?) throws -> View {
        self.allAuthorsURI = uri
        self.allAuthorsTwitterHandle = siteTwitterHandle
        self.allAuthorsPageAuthors = allAuthors
        return View(data: try "Test".makeBytes())
    }
    
    private(set) var allTagsTwitterHandle: String? = nil
    private(set) var allTagsURI: URI? = nil
    private(set) var allTagsPageTags: [BlogTag]? = nil
    func allTagsView(uri: URI, allTags: [BlogTag], user: BlogUser?, siteTwitterHandle: String?) throws -> View {
        self.allTagsURI = uri
        self.allTagsTwitterHandle = siteTwitterHandle
        self.allTagsPageTags = allTags
        return View(data: try "Test".makeBytes())
    }
}
