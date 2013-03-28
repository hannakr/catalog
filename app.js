
/**
 * Module dependencies.
 */

var express = require('express')
  , pages = require('./routes/pages')
  , create = require('./routes/create')
  , projects = require('./routes/projects')
  , http = require('http')
  , path = require('path')
  , fs = require('fs')
  , nodemailer = require("nodemailer")
  , config = require("./modules/config").config
  , migrate = require('db-migrate');

var app = express();

// App Configuration

app.configure(function(){
  app.set('port', process.env.PORT || 3000);
  app.set('views', __dirname + '/views');
  app.set('view engine', 'ejs');
  app.use(express.favicon());
  app.use(express.logger('dev'));
  app.use(express.bodyParser({uploadDir:'./uploads'}));
  app.use(express.methodOverride());
  app.use(app.router);
  app.use(express.static(path.join(__dirname, 'public')));
  app.use('/public', express.static(__dirname + '/public'));
});

app.configure('development', function(){
  app.use(express.errorHandler());
});

// Nodemailer Setup 

var smtpTransport = nodemailer.createTransport("SMTP",{
    service: config.mail.service,
    auth: {
        user: config.mail.username,
        pass: config.mail.password
    }
});

// Routes for website
app.get('/', pages.index);
app.get('/about', pages.about);

app.get('/create', create.get);
app.post('/submit', create.submit, create.done);

// Route for individual projects
// app.get('/:program/:author', function(req, res) {
//     // just a stub for now, and we'll be rendering not returning JSON
//     res.send({program:req.params.program, name: req.params.author, description: "description"});
// });

// Routes that return JSON

app.get('/:degreeTrack', projects.getProjectsForDegreeTrack);



// Servin' it up
http.createServer(app).listen(app.get('port'), function(){
  console.log("Express server listening on port " + app.get('port'));
});
 