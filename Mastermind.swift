import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Data Structures
struct GameResponse: Codable { let game_id: String }
struct GuessRequest: Codable { let game_id: String; let guess: String }
struct GuessResponse: Codable { let black: Int; let white: Int }
struct ErrorResponse: Codable { let error: String }

// MARK: - Mastermind API Client
class MastermindClient {
    let baseURL = URL(string: "https://mastermind.darkube.app")!

    func startGame(completion: @escaping (String?) -> Void) {
        let url = baseURL.appendingPathComponent("/game")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let resp = try? JSONDecoder().decode(GameResponse.self, from: data) {
                completion(resp.game_id)
            } else {
                completion(nil)
            }
        }.resume()
    }

    func makeGuess(gameId: String, guess: String, completion: @escaping (GuessResponse?) -> Void) {
        let url = baseURL.appendingPathComponent("/guess")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(GuessRequest(game_id: gameId, guess: guess))

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let resp = try? JSONDecoder().decode(GuessResponse.self, from: data) {
                completion(resp)
            } else {
                completion(nil)
            }
        }.resume()
    }

    func deleteGame(gameId: String, completion: (() -> Void)? = nil) {
        let url = baseURL.appendingPathComponent("/game/\(gameId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { _, _, _ in
            completion?()
        }.resume()
    }
}

// MARK: - Utilities for Terminal Display
func printDivider() {
    print(String(repeating: "=", count: 50))
}

func printHeader(_ text: String) {
    printDivider()
    print("  \(text)")
    printDivider()
}

func printResult(black: Int, white: Int) {
    let blackBar = String(repeating: "*", count: black)
    let whiteBar = String(repeating: "o", count: white)
    print("  Result -> Black: \(black) [\(blackBar)]  White: \(white) [\(whiteBar)]\n")
}

// MARK: - Main Game Loop
let client = MastermindClient()
printHeader("Welcome to Mastermind")
print("Starting a new game...")

client.startGame { gameId in
    guard let gameId = gameId else {
        print("Failed to start game.")
        exit(1)
    }

    print("Game ID: \(gameId)")
    print("Enter your guesses (4 digits, 1-6). Type 'exit' to quit.\n")

    func askGuess() {
        print("Enter guess:", terminator: " ")
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty else {
            print("Invalid input. Try again.\n")
            askGuess()
            return
        }

        if input.lowercased() == "exit" {
            client.deleteGame(gameId: gameId) {
                print("\nThank you for playing. Goodbye!")
                exit(0)
            }
            return
        }

        guard input.count == 4, input.allSatisfy({ ["1","2","3","4","5","6"].contains(String($0)) }) else {
            print("Invalid guess. Must be exactly 4 digits from 1 to 6.\n")
            askGuess()
            return
        }

        client.makeGuess(gameId: gameId, guess: input) { result in
            if let result = result {
                printResult(black: result.black, white: result.white)
                if result.black == 4 {
                    printDivider()
                    print("Congratulations! You've cracked the code!")
                    printDivider()
                    client.deleteGame(gameId: gameId) {
                        exit(0)
                    }
                } else {
                    askGuess()
                }
            } else {
                print("Failed to get result. Try again.\n")
                askGuess()
            }
        }
    }

    askGuess()
}

// Keep program alive for async callbacks
RunLoop.main.run()
