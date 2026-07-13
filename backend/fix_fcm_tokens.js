// Script to fix FCM tokens and associate with admin
const mongoose = require('mongoose');
require('dotenv').config();
const db = require('./config/db');

async function fixFCMTokensAndAssociateAdmin() {
  await db();
  
  // Get admin ID
  const admin = await mongoose.connection.db.collection('admins').findOne({});
  if (!admin) {
    console.log('No admin found');
    process.exit(1);
  }
  console.log('Admin found:', admin._id, admin.username);
  
  // Get all FCM tokens
  const fcmTokens = await mongoose.connection.db.collection('fcmtokens').find({}).toArray();
  console.log('\nFCM tokens found:', fcmTokens.length);
  
  // Show current state and fix each token
  for (const t of fcmTokens) {
    console.log('\n  Token ID:', t._id);
    console.log('    user_id:', t.user_id);
    console.log('    user_type:', t.user_type);
    console.log('    user_model:', t.user_model);
    console.log('    is_active:', t.is_active);
    console.log('    token:', t.token?.substring(0, 40) + '...');
  }
  
  // Update the admin token to have proper fields
  const adminToken = await mongoose.connection.db.collection('fcmtokens').findOne({ user_type: 'admin' });
  if (adminToken) {
    await mongoose.connection.db.collection('fcmtokens').updateOne(
      { _id: adminToken._id },
      { 
        $set: { 
          user_model: 'Admin',
          is_active: true,
          last_updated: new Date()
        } 
      }
    );
    console.log('\n✅ Updated admin FCM token with is_active: true and user_model: Admin');
  } else {
    // If no admin token exists, update the latest token
    if (fcmTokens.length > 0) {
      const latestToken = fcmTokens[fcmTokens.length - 1];
      await mongoose.connection.db.collection('fcmtokens').updateOne(
        { _id: latestToken._id },
        { 
          $set: { 
            user_id: admin._id,
            user_type: 'admin',
            user_model: 'Admin',
            is_active: true,
            last_updated: new Date()
          } 
        }
      );
      console.log('\n✅ Associated and activated latest FCM token with admin:', admin.username);
    }
  }
  
  // Verify
  console.log('\n========== VERIFICATION ==========');
  const verifiedToken = await mongoose.connection.db.collection('fcmtokens').findOne({ user_type: 'admin' });
  if (verifiedToken) {
    console.log('Admin token after update:');
    console.log('  user_id:', verifiedToken.user_id);
    console.log('  user_type:', verifiedToken.user_type);
    console.log('  user_model:', verifiedToken.user_model);
    console.log('  is_active:', verifiedToken.is_active);
    console.log('  token:', verifiedToken.token?.substring(0, 30) + '...');
  }
  
  process.exit(0);
}

fixFCMTokensAndAssociateAdmin().catch(e => { console.error(e); process.exit(1); });
