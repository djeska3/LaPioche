import Fluent
import Vapor

struct GameController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let games = routes.grouped("games")
        games.get(use: index)
        games.post(use: create)
        games.get(":gameID", use: show)
        games.put(":gameID", use: update)
    }

    @Sendable
    func index(req: Request) async throws -> [GameDTO] {
        let games = try await Game.query(on: req.db)
            .with(\.$loans)
            .all()
        return games.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        try CreateGameDTO.validate(content: req)
        let dto = try req.content.decode(CreateGameDTO.self)
        try dto.ensureConsistentPlayerCount()

        let game = dto.toModel()
        try await game.save(on: req.db)
        return try await game.toDTO().encodeResponse(status: .created, for: req)
    }

    @Sendable
    func show(req: Request) async throws -> GameDTO {
        try await findGame(req).toDTO()
    }

    private func findGame(_ req: Request) async throws -> Game {
        guard let gameID = req.parameters.get("gameID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid game id")
        }
        guard let game = try await Game.query(on: req.db)
            .filter(\.$id == gameID)
            .with(\.$loans)
            .first()
        else {
            throw Abort(.notFound, reason: "Game not found")
        }
        return game
    }
    
    @Sendable
    func update(req: Request) async throws -> CreateGameDTO {
           guard let id = req.parameters.get("gameID", as: UUID.self)
           else {
               throw Abort(.badRequest, reason: "ID isn't correct")
           }
           guard let game = try await Game.find(id, on: req.db)
           else {
               throw Abort(.notFound, reason: "Game doesn't exist")
           }
           
           let gameUpdateDTO = try req.content.decode(CreateGameDTO.self)
        guard !gameUpdateDTO.title.isEmpty else {
            throw Abort(.badRequest, reason: "Title is empty")
        }
        guard gameUpdateDTO.minPlayers <= gameUpdateDTO.maxPlayers else {
            throw Abort(.badRequest, reason: "Min. players needs to be lower or equal to maxPlayers.")
        }
        guard gameUpdateDTO.durationMinutes > 0 else {
            throw Abort(.badRequest, reason: "Duration need to be higher than 0.")
        }
           
        game.title = gameUpdateDTO.title
        game.minPlayers = gameUpdateDTO.minPlayers
        game.maxPlayers = gameUpdateDTO.maxPlayers
        game.durationMinutes = gameUpdateDTO.durationMinutes
        
           try await game.update(on: req.db)
           return gameUpdateDTO
       }
}
