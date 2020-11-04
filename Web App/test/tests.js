/*
 * Test for Grad Catalog
 * run 'mocha -R nyan' from project root for maximum test delightfulness
 *
 */


var chai = require('chai')
  ,  expect = chai.expect
  , chaiHttp = require('chai-http')
  , baseURL = 'http://localhost:3000';

chai.use(chaiHttp);


describe('Grad Catalog Tests', function() {
    describe('Home page URL', function() {
        it('should return 200 OK', function(done) {
            chai.request(baseURL)
            .get('/2020/home')
            .end(function(err, res) {
                expect(res).to.have.status(200);
                done();
            });
        });
    });    

    describe('About page URL', function() {
        it('should return 200 OK', function(done) {
            chai.request(baseURL)
            .get('/about')
            .end(function(err, res) {
                expect(res).to.have.status(200);
                done();
            });
        });
    });

    describe('json/:degree', function() {
        it('should return 200 OK', function(done) {
            chai.request(baseURL)
            .get('/json')
            .end(function (err, res) {
                expect(res).to.have.status(200);
                expect(res).to.be.json;
                done();
            });
        });
    });

    describe('Testing submission form', function() {
        it('should submit happily', function() {
            //Should expect something here, but what? Refer to API for testing form submission.
        });
    })
});




