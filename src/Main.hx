// MAIN HX : Une fois compilé , ce fichier nous permettra d'obtenir le main.js qui sera notre fichier qui fera tourner le serveur.


import js.npm.express.Static; // Middleware Express qui permet d'accéder à des fichiers statiques. 
import js.npm.ws.WebSocket; // Module Websocket : Il va nous permettre d'emettre et de recevoir des données entre le client et le serveur : coté client.
import js.Node; // Module Node.
import js.npm.express.Request; // Objet Express Request : Qui permet de récupérer les requetes faites au serveur.
import js.npm.express.Response; // Objet Express Response : Objet renvoyé par la réponse.
import js.npm.Express; // Module Express : qui va nous permettre de lancer notre serveur 
import js.npm.express.BodyParser; // MiddleWare qui permet de parser les données envoyées dans la requete. 
import js.npm.express.Session; // Middleware qui permet de gérer les différentes sessions.
import js.npm.ws.Server as WSServer; // Module Websocket : Il va nous permettre d'emettre et de recevoir des données entre le client et le serveur : coté serveur.
import TypeDefinitions; 




// Cette ligne nous permet de créer l'objet Session.
extern class RequestWithSession extends Request {
	public var session:{token:String};
}

// Cette ligne nous permet de créer l'objet body qui va stocker les infomration du formulaire de login. 
extern class RequestLogin extends RequestWithSession {
	public var body:{username:String, password:String};
}

// Cette ligne nous permet de créer l'objet body qui va stocker les infomration du formulaire d'inscription. 


extern class RequestSubscribe extends RequestWithSession {
	public var body:{username:String, password:String, email:String};
}


extern class RequestSave extends RequestWithSession {
	public var body:Dynamic;
}


//Déclaration de  l'objet main , une fois compilé va nous permettre de lancer notre serveur et de le faire fonctionner.


class Main {
	// Declare a static property with a get but no setter. See https://haxe.org/manual/class-field-property.html
	// Act as a readonly singleton.
	static var mysqlDB(default, never):MySQL = Node.require("mysql"); // On récupere le module my.sql.

	static var lastSocketId:Int = 0; // On crée une variable qui va contenir l'id du dernier socket.
	static var sockets:List<WebSocket> = new List<WebSocket>(); // Cette variable va contenir l'ensemble des id de tous les sockets connectés.
	static var tickets:Map<String, String> = new Map<String, String>(); // Ce tableau va contenir tous les tickets de clients connectés au serveur.


	static function main() {
		// load environment variables from .env file
		// .env file must be present at the location the "node" command is run (Working directory)
		Node.require('dotenv').config();
		var cors = Node.require('cors');

		// create a connection to the database and start the connection immediatly
		var connection = mysqlDB.createConnection({
			host: Sys.getEnv("DB_HOST"),
			user: Sys.getEnv("DB_USER"),
			password: Sys.getEnv("DB_PASSWORD"),
			database: Sys.getEnv("DB_NAME")
		});
		connection.connect();

		// Setup express server with middlewares
		var server:Express = new js.npm.Express();
		server.use(BodyParser.json({limit: '5mb', type: 'application/json'}));


		server.use(cors({
			credentials: true,
			origin: function(req:Request, callback:String->Bool->Void) {
				callback(null, true);
			}


	
		}));
		server.use(new Static("wsclient"));
		server.use(new Session({
			secret: 'shhhh, very secret',
			resave: true,
			saveUninitialized: true
		}));

		var expressWs = Node.require('express-ws')(server);

		expressWs.app.ws('/', function(socket:WebSocket, req) {
			// use a closure to keep socket related data
			// if username have a value the user is logged in.
			var username:String = null;

// Ecoute du socket : Si l'utilisateur se deconnecte
			socket.on('close', function() {
				sockets.remove(socket);
				if (username == null)
					return;
				for (remoteSocket in sockets) {
					remoteSocket.send(username + " disconnected !", null); // Message de deconnexion.
				}


			});


// Ecoute du socket : Si l'utilisateur se connecte. 

			socket.on('message', function(msg:Dynamic) {
				if (username == null) {
					if (tickets.exists(msg)) {
						// allow socket to talk by setting its username
						username = tickets[msg];
						// consume ticket
						tickets.remove(msg);
						// add socket to destination list
						sockets.add(socket);
						// welcome
						socket.send("Bienvenue sur le chat " + username, null); // Si il possède un ticket on lui donne accès au chat et on lui affiche un message de bienvenue.
					} else {
						socket.send("Please provide a ticket first to log in.", null); // Si il ne possède pas de ticket , on lui demande de s'en créer.
						socket.close();
					}
					return;
				}
				for (remoteSocket in sockets) {
					remoteSocket.send(username + " : " + Std.string(msg), null);
				}
			});
		});

	// Création des différentes routes.
		/**
		 * @api {get} /random Random
		 * @apiDescription Return a random number between 0 and 1
		 * @apiName Random
		 * @apiGroup Random
		 *
		 * @apiSuccessExample Success-Response:
		 *     HTTP/1.1 200 OK
		 *     0.546821
		 */

		 // Cette route nous renvoie un nombre random contenu sous forme de string.
		server.get('/random', function(req:Request, res:Response) {
			res.writeHead(200, {'Content-Type': 'text/plain'});
			res.end(Std.string(Math.random()));
		});

		/**
		 * @api {post} /login Login
		 * @apiDescription Authenticate a registered user
		 * @apiName Login
		 * @apiGroup Users
		 *
		 * @apiParam {String} username Login used by the user
		 * @apiParam {String} password Password to check
		 *
		 * @apiSuccessExample Success-Response:
		 *     HTTP/1.1 200 OK
		 *     OK
		 *
		 * @apiError (Error 401) Unauthorized Authentication information doesn't match.
		 * @apiError (Error 500) MissingInformation Could not register the user because some information is missing.
		 * @apiError (Error 500) TechnicalError Could not create user because of technical error %s.
		 *
		 * @apiErrorExample Error-Response:
		 *     HTTP/1.1 500 Unauthorized
		 *     {
		 *        "errorKey": "Unauthorized",
		 *        "errorMessage": "Authentication information doesn't match.",
		 *      }
		 */


		 // Cette route permet de recuperer le formulaire de connexion envoyé.
		server.post('/login', function(expressReq:Request, res:Response) {
			var req:RequestLogin = cast(expressReq);
			switch (req.body) {
				case {username: uname, password: pwd}
					if (uname == null || pwd == null): //Cas ou le formulaire est vide.
					// username and password must be provided   
					req.session.token = null;
					res.send(400, "Bad Request");
				case {username: username, password: password}: // Cas ou le formulaire n'est pas vide;
					db.User.userExists(connection, username, password, result -> switch (result) { 
						case UserExistsResult.Error(err): // Cas ou UserExists renvoie une erreur. 
							trace(err);
							res.send(500, err.message); // Si tel est le cas on renvoie un message d'erreur.

						case UserExistsResult.Yes: // Cas ou UserExits ne renvoie pas d'erreur et trouve le User.
						//Création d'un token dans la BD.
							db.Token.createToken(connection, username, 59, createTokenResult -> switch createTokenResult {
								case OK(token): // Cas ou le token a été créé.
									req.session.token = token;
									res.send(200, "OK"); // Se connecte à la Db.
								case Error(err): // Cas ou il y a une erreur sur token.
									trace(err);
									res.send(500, err.message); //On renvoie un message d'erreur.
							});

					// Au cas ou un des deux est faux ( soit le mot de passe , soit le nom d'utilisateur.)
						case UserExistsResult.Missing | UserExistsResult.WrongPassword:
							req.session.token = null;
							res.send(401, "Unauthorized"); // On renvoie le message d'erreur.
					});
			}
		});

		/**
		 * @api {post} /subscribe Subscribe
		 * @apiDescription Register a new user
		 * @apiName Subscribe
		 * @apiGroup Users
		 *
		 * @apiParam {String} username Login that will be used by the user
		 * @apiParam {String} password Password to use for authentication
		 * @apiParam {String} email Email
		 *
		 * @apiSuccessExample Success-Response:
		 *     HTTP/1.1 200 OK
		 *     OK
		 *
		 * @apiError (Error 500) MissingInformation Could not register the user because some information is missing.
		 * @apiError (Error 500) UserCreationFailed Could not create nor find user %s.
		 * @apiError (Error 500) TechnicalError Could not create user because of technical error %s.
		 *
		 * @apiErrorExample Error-Response:
		 *     HTTP/1.1 500 MissingInformation
		 *     {
		 *        "errorKey": "MissingInformation",
		 *        "errorMessage": "Could not register the user because some information is missing.",
		 *      }
		 */

		 // Cette route permet de recuperer le formulaire d'incscription.
		 // Comme dans la route précendente , nous avons différents cas , mais ceux ci s'affichent lorsque l'utilisateur tente de s'inscrire.

		server.post('/subscribe', function(expressReq:Request, res:Response) {
			var req:RequestSubscribe = cast(expressReq);
			switch (req.body) {
				case {username: username, password: password, email: email}
					if (username == null || password == null || email == null):
					res.send(400, "Username and password and email must be provided");
				case {username: username, password: password, email: email}:
					db.User.userExists(connection, username, password, result -> switch (result) {
						case UserExistsResult.Error(err):
							trace(err);
							res.send(500, err.message);
						case UserExistsResult.Yes, UserExistsResult.WrongPassword:
							res.send(500, "User already exists, please use another login");
						case UserExistsResult.Missing:
							db.User.createUser(connection, {
								username: username,
								password: password,
								email: email
							}, response -> switch (response) {
								case Error(err):
									res.send(500, "An error occured\n" + err.message);
								case OK(_):
									res.send(200, "OK");
							});
					});
			}
		});


		//Cette route permet à l'user de se deconnecter.
		server.post('/logout', function(expressReq:Request, res:Response) {
			var req:RequestWithSession = cast(expressReq);
			req.session.token = null;
			res.send(200, "OK");
			return;
		});

		// Cette route permet de donner à l'utilisateur un statut.
		server.get('/status', function(expressReq:Request, res:Response) {
			var req:RequestWithSession = cast(expressReq);
			if (req.session.token == null) {
				res.send(200, "Visiteur"); // Si le token de session de l'utilisateur est nul , il est un simple visiteur.
				return;
			}


			db.Token.fromToken(connection, req.session.token, result -> switch (result) {
				case User(login): // Si le token de l'utilisateur appartient à la DB.
					res.send(200, "Bonjour " + login);
				case Missing: // Si le token de l'utilisateur n'appartient pas  à la DB.
					res.send(401, "Token invalide. Vous devez vous re-connecter.");
				case Error(err): // Si il y a une erreur.
					res.send(500, err);
			});
		});

		// Cette route permet de sauvegarder le token en BD.

		server.post('/save', function(expressReq:Request, res:Response) {
			var req:RequestSave = cast(expressReq);
			if (req.session.token == null) {
				res.send(401, "Token invalide. Vous devez vous re-connecter.");
				return;
			}
			db.Token.fromToken(connection, req.session.token, result -> switch (result) {
				case User(login):
					db.User.save(connection, login, req.body, result -> switch (result) {
						case Error(err):
							res.send(500, "An error occured\n" + err.message);
						case OK(_):
							res.send(200, "OK");
					});
				case Missing:
					res.send(401, "Token invalide. Vous devez vous re-connecter.");
				case Error(err):
					res.send(500, err);
			});
		});

		server.post('/load', function(expressReq:Request, res:Response) {
			var req:RequestSave = cast(expressReq);
			if (req.session.token == null) {
				res.send(401, "Token invalide. Vous devez vous re-connecter.");
				return;
			}
			db.Token.fromToken(connection, req.session.token, result -> switch (result) {
				case User(login):
					db.User.load(connection, login, result -> switch (result) {
						case Error(err):
							res.send(500, "An error occured\n" + err.message);
						case OK(data):
							res.send(200, data);
					});
				case Missing:
					res.send(401, "Token invalide. Vous devez vous re-connecter.");
				case Error(err):
					res.send(500, err);
			});
		});


// Cette route permet d'attribuer des tickets.
		server.get('/wsTicket', function(expressReq:Request, res:Response) {
			var req:RequestWithSession = cast(expressReq);
			if (req.session.token == null) {
				res.send(401, "Token invalide. Vous devez vous re-connecter.");
				return;
			}
			db.Token.fromToken(connection, req.session.token, result -> switch (result) {
				case User(login):
					var ticket = haxe.crypto.BCrypt.generateSalt().substr(0, 32);
					tickets[ticket] = login;
					res.send(200, ticket);
				case Missing:
					res.send(401, "Token invalide. Vous devez vous re-connecter.");
				case Error(err):
					res.send(500, err);
			});
		});

		var port = 1337; // Initialisation du port du serveur.

		// Si dans le fichier .env l'objet port n'est pas nul 
		if (Sys.getEnv("PORT") != null) {
			port = Std.parseInt(Sys.getEnv("PORT")); // La variable port prendra la valeur du PORT en .env
		}
		server.listen(port); //On écoute le serveur sur le port défini.
		trace('Server running at http://localhost:${port}/');
		Node.process.on('SIGTERM', function onSigterm() {
			trace('Got SIGTERM. Graceful shutdown start');
			connection.end();
		});
	}
}
