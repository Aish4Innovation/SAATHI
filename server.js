const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const twilio = require('twilio');
const cron = require('node-cron'); // ADDED: New dependency for scheduling tasks

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

// Serve uploaded images statically
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'ramco', 
  database: 'saathi',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Configure Multer for file uploads
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    cb(null, `${Date.now()}-${file.originalname}`);
  }
});

const upload = multer({ storage: storage });

// Configure Twilio with your credentials
const accountSid = 'AC4eea05a14ae3d96b3cd8701db7789ed2';
const authToken = '88467bf8c94979abf98d94dbc0ba7b9f';
const twilioPhoneNumber = '+15075026181';
const client = twilio(accountSid, authToken);

// ADDED: A reusable function to send the caregiver notification via Twilio
async function sendCaregiverNotification(userId, medicineName) {
  // Fetch the primary caregiver's phone number
  const query = 'SELECT phone_number FROM caregivers WHERE user_id = ? AND is_primary = TRUE LIMIT 1';
  try {
    const [results] = await pool.promise().execute(query, [userId]);

    if (results.length === 0 || !results[0].phone_number) {
      console.log(`No primary caregiver number found for userId: ${userId}`);
      return;
    }

    const caregiverPhoneNumber = results[0].phone_number;
    const message = `Reminder: Your loved one has missed their ${medicineName} dose. Please check in with them.`;

    // Use the Twilio client to send the SMS
    const twilioMessage = await client.messages.create({
      body: message,
      from: twilioPhoneNumber,
      to: caregiverPhoneNumber
    });

    console.log(`SMS sent to ${caregiverPhoneNumber}. SID: ${twilioMessage.sid}`);
  } catch (error) {
    console.error('Error sending SMS via Twilio:', error);
  }
}

app.get('/', (req, res) => {
  res.send('Saathi API is running!');
});

// GET route to fetch a single user profile by ID
app.get('/api/profile/:id', (req, res) => {
  const userId = req.params.id;
  const query = 'SELECT name FROM profiles WHERE id = ?';
  pool.execute(query, [userId], (err, results) => {
    if (err) {
      console.error('Error fetching profile:', err);
      return res.status(500).send('Error fetching user profile.');
    }
    if (results.length === 0) {
      return res.status(404).send('User not found.');
    }
    res.status(200).json(results[0]);
  });
});

// POST route to handle user onboarding data (from SetupScreen)
app.post('/api/profile', (req, res) => {
  const { name, age } = req.body;

  if (!name || !age) {
    return res.status(400).send('Name and age are required.');
  }

  const query = 'INSERT INTO profiles (name, age) VALUES (?, ?)';
  pool.execute(query, [name, age], (err, result) => {
    if (err) {
      console.error('Error inserting data into profiles:', err);
      return res.status(500).send('Error saving user profile.');
    }
    console.log('Profile saved successfully:', result);
    res.status(201).send({ message: 'Profile saved successfully!', userId: result.insertId });
  });
});

// POST route to add a new medicine with file upload
app.post('/api/medicines', upload.single('photo'), (req, res) => {
  const { userId, name, dosage, time, start_date, end_date } = req.body;
  const photo_url = req.file ? `/uploads/${req.file.filename}` : null;

  if (!userId || !name || !time || !start_date) {
    return res.status(400).send('userId, name, time, and start_date are required.');
  }

  const query = 'INSERT INTO medicines (user_id, name, dosage, time, start_date, end_date, photo_url) VALUES (?, ?, ?, ?, ?, ?, ?)';
  pool.execute(query, [userId, name, dosage, time, start_date, end_date, photo_url], (err, result) => {
    if (err) {
      console.error('Error inserting medicine:', err);
      return res.status(500).send('Error saving medicine.');
    }
    console.log('Medicine saved successfully:', result);
    res.status(201).send({ message: 'Medicine saved successfully!', medicineId: result.insertId });
  });
});

// GET route to fetch all medicines for a specific user
app.get('/api/medicines/:userId', (req, res) => {
  const userId = req.params.userId;
  const query = 'SELECT id, name, dosage, time, is_taken, photo_url FROM medicines WHERE user_id = ?';
  pool.execute(query, [userId], (err, results) => {
    if (err) {
      console.error('Error fetching medicines:', err);
      return res.status(500).send('Error fetching medicines.');
    }
    res.status(200).json(results);
  });
});

// PUT route to update a medicine's status
app.put('/api/medicines/:medicineId', (req, res) => {
  const medicineId = req.params.medicineId;
  const { is_taken } = req.body;
  
  if (is_taken === undefined) {
    return res.status(400).send('is_taken field is required.');
  }

  const query = `UPDATE medicines SET is_taken = ? WHERE id = ?`;
  pool.execute(query, [is_taken, medicineId], (err, result) => {
    if (err) {
      console.error('Error updating medicine status:', err);
      return res.status(500).send('Error updating medicine status.');
    }
    if (result.affectedRows === 0) {
      return res.status(404).send('Medicine not found.');
    }
    console.log('Medicine status updated successfully:', result);
    res.status(200).send({ message: 'Medicine status updated successfully.' });
  });
});

// NEW POST route to notify the caregiver (now calls the reusable function)
app.post('/api/notify-caregiver', (req, res) => {
  const { userId, medicineName } = req.body;

  if (!userId || !medicineName) {
    return res.status(400).send('userId and medicineName are required.');
  }
  
  sendCaregiverNotification(userId, medicineName)
    .then(() => {
      res.status(200).send({ message: 'Caregiver notification sent successfully.' });
    })
    .catch(error => {
      console.error('Error in notify-caregiver route:', error);
      res.status(500).send('Failed to send caregiver notification.');
    });
});

// API ENDPOINTS FOR CAREGIVER MANAGEMENT
// ... (Your caregiver routes remain unchanged) ...
// GET route to fetch all caregivers for a specific user
app.get('/api/caregivers/:userId', (req, res) => {
  const userId = req.params.userId;
  const query = 'SELECT id, name, phone_number, relationship, is_primary FROM caregivers WHERE user_id = ?';
  pool.execute(query, [userId], (err, results) => {
    if (err) {
      console.error('Error fetching caregivers:', err);
      return res.status(500).send('Error fetching caregivers.');
    }
    res.status(200).json(results);
  });
});

// POST route to add a new caregiver
app.post('/api/caregivers', (req, res) => {
  const { userId, name, phoneNumber, relationship, isPrimary } = req.body;

  if (!userId || !name || !phoneNumber) {
    return res.status(400).send('userId, name, and phoneNumber are required.');
  }

  const query = 'INSERT INTO caregivers (user_id, name, phone_number, relationship, is_primary) VALUES (?, ?, ?, ?, ?)';
  pool.execute(query, [userId, name, phoneNumber, relationship, isPrimary], (err, result) => {
    if (err) {
      console.error('Error adding caregiver:', err);
      return res.status(500).send('Error adding new caregiver.');
    }
    console.log('Caregiver added successfully:', result);
    res.status(201).send({ message: 'Caregiver added successfully!', caregiverId: result.insertId });
  });
});

// NEW PUT route to update a caregiver
app.put('/api/caregivers/:caregiverId', (req, res) => {
  const caregiverId = req.params.caregiverId;
  const { name, phoneNumber, relationship, isPrimary } = req.body;

  if (!name && !phoneNumber && !relationship && isPrimary === undefined) {
    return res.status(400).send('At least one field (name, phoneNumber, relationship, or isPrimary) is required for update.');
  }

  let query = 'UPDATE caregivers SET';
  const queryParams = [];
  
  if (name !== undefined) {
    query += ' name = ?,';
    queryParams.push(name);
  }
  if (phoneNumber !== undefined) {
    query += ' phone_number = ?,';
    queryParams.push(phoneNumber);
  }
  if (relationship !== undefined) {
    query += ' relationship = ?,';
    queryParams.push(relationship);
  }
  if (isPrimary !== undefined) {
    query += ' is_primary = ?,';
    queryParams.push(isPrimary);
  }

  query = query.slice(0, -1) + ' WHERE id = ?';
  queryParams.push(caregiverId);

  pool.execute(query, queryParams, (err, result) => {
    if (err) {
      console.error('Error updating caregiver:', err);
      return res.status(500).send('Error updating caregiver.');
    }
    if (result.affectedRows === 0) {
      return res.status(404).send('Caregiver not found.');
    }
    console.log('Caregiver updated successfully:', result);
    res.status(200).send({ message: 'Caregiver updated successfully.' });
  });
});

// DELETE route to remove a caregiver
app.delete('/api/caregivers/:caregiverId', (req, res) => {
  const caregiverId = req.params.caregiverId;
  const query = 'DELETE FROM caregivers WHERE id = ?';
  pool.execute(query, [caregiverId], (err, result) => {
    if (err) {
      console.error('Error deleting caregiver:', err);
      return res.status(500).send('Error deleting caregiver.');
    }
    if (result.affectedRows === 0) {
      return res.status(404).send('Caregiver not found.');
    }
    console.log('Caregiver deleted successfully:', result);
    res.status(200).send({ message: 'Caregiver deleted successfully.' });
  });
});

// ADDED: Scheduled task to check for missed medicine doses every 15 minutes
cron.schedule('*/15 * * * *', async () => {
  console.log('Running scheduled check for missed medicine doses...');
  const currentTime = new Date();
  const thirtyMinutesAgo = new Date(currentTime.getTime() - (30 * 60 * 1000));
  
  // Format the current date and time parts for the SQL query
  const currentDate = thirtyMinutesAgo.toISOString().split('T')[0]; // YYYY-MM-DD
  const thirtyMinutesAgoTime = thirtyMinutesAgo.toTimeString().split(' ')[0]; // HH:MM:SS
  
  try {
    // This query now checks if a medicine was due today (based on start_date)
    // and if its scheduled time was more than 30 minutes ago.
    const [medicines] = await pool.promise().execute(
      'SELECT user_id, name FROM medicines WHERE start_date <= ? AND time <= ? AND is_taken = 0',
      [currentDate, thirtyMinutesAgoTime]
    );

    if (medicines.length > 0) {
      console.log(`Found ${medicines.length} missed medicine doses.`);
      // Loop through each missed medicine and send a notification
      for (const medicine of medicines) {
        await sendCaregiverNotification(medicine.user_id, medicine.name);
      }
    } else {
      console.log('No missed medicine doses found.');
    }
  } catch (err) {
    console.error('Error in scheduled task:', err);
  }
});

app.listen(port, () => {
  console.log(`Saathi API is listening on http://localhost:${port}`);
});