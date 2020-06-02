const express = require('express');

const index = express();

index.use(express.json());

const http = require('http'); 

const port = process.env.PORT || 8081;

const server = http.createServer(index);

server.listen(port);

 

const characters = [

  {
    id: 1,
    name: "Walter White",
    birthday: "09-07-1958",
    occupation: [
        "High School Chemistry Teacher",
        "Meth King Pin"
    ],
    img: "https://images.amcnetworks.com/amc.com/wp-content/uploads/2015/04/cast_bb_700x1000_walter-white-lg.jpg",
    status: "Deceased",
    appearance: [1, 2, 3, 4, 5],
    nickname: "Heisenberg",
    portrayed: "Bryan Cranston"
},

{
  id: 2,
  name: "Jesse Pinkman",
  birthday: "09-24-1984",
  occupation: [
      "Meth Dealer"
  ],
  img: "https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Jesse_Pinkman2.jpg/220px-Jesse_Pinkman2.jpg",
  status: "Alive",
  nickname: "Cap n' Cook",
  appearance: [
      1,
      2,
      3,
      4,
      5
  ],
  portrayed: "Aaron Paul",
  category: "Breaking Bad",
  better_call_saul_appearance: []
},

{
  id: 3,
  name: "Skyler White",
  birthday: "08-11-1970",
  occupation: [
      "House wife",
      "Book Keeper",
      "Car Wash Manager",
      "Taxi Dispatcher"
  ],
  img: "https://s-i.huffpost.com/gen/1317262/images/o-ANNA-GUNN-facebook.jpg",
  status: "Alive",
  nickname: "Sky",
  appearance: [
      1,
      2,
      3,
      4,
      5
  ],
  portrayed: "Anna Gunn",
  category: "Breaking Bad",
  better_call_saul_appearance: []
},

];

 

index.get('/', (req, res) => {

    res.status(200).json({

        message:'Breaking Bad API'

    });

});

 
index.get('/api/characters', (req, res) => {

  res.send([characters]);

 

});

 

index.post('/api/characters', (req, res) => {

    const character = {

    id: characters.length + 1,

    name: req.body.name

 

    };

    characters.push(character);

    res.send(character);

  

});







index.get('/api/characters/:id', (req, res) => {

    const character = characters.find(c => c.id === parseInt(req.params.id))

    if (!character) res.status(404).send('The character with the given ID was not found');

    res.send(character);

 

  

  });

module.exports = index;
