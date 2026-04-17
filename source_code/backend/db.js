const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres@localhost:5432/delisure',
});

const query = (text, params) => pool.query(text, params);

module.exports = { pool, query };
