const admin = require('firebase-admin');

const getFirestore = () => {
  if (!admin.apps.length) {
    throw new Error('Firebase Admin SDK not initialized.');
  }
  return admin.firestore();
};

const PKG = (db, userId) => db.collection('app_users').doc(userId).collection('packages');

const createPackage = async (userId, data) => {
  const db = getFirestore();
  const col = PKG(db, userId);
  const now = new Date();
  const payload = {
    name: data?.name || `Paket ${now.toISOString()}`,
    createdAt: now,
    lastUpdatedAt: now,
    status: 'uploading', // uploading -> queued -> processing -> completed|failed|partial
    totalInvoices: data?.totalInvoices ?? 0,
    processedInvoices: 0,
    errorCount: 0,
    approvedInvoices: 0,
  };
  const ref = await col.add(payload);
  return { id: ref.id, ...payload };
};

const updatePackage = async (userId, packageId, data) => {
  const db = getFirestore();
  const doc = PKG(db, userId).doc(packageId);
  await doc.update({ ...data, lastUpdatedAt: new Date() });
};

const incrementCounters = async (userId, packageId, { processed = 0, errors = 0, approved = 0 } = {}) => {
  const db = getFirestore();
  const doc = PKG(db, userId).doc(packageId);
  await doc.update({
    processedInvoices: admin.firestore.FieldValue.increment(processed),
    errorCount: admin.firestore.FieldValue.increment(errors),
    approvedInvoices: admin.firestore.FieldValue.increment(approved),
    lastUpdatedAt: new Date(),
  });
};

// Package status'unu güncelle
const updatePackageStatus = async (userId, packageId) => {
  const db = getFirestore();
  const doc = PKG(db, userId).doc(packageId);
  const packageData = (await doc.get()).data();
  
  if (!packageData) return;
  
  const { totalInvoices, processedInvoices, errorCount } = packageData;
  let newStatus = 'uploading';
  
  if (processedInvoices + errorCount >= totalInvoices) {
    if (errorCount === 0) {
      newStatus = 'completed';
    } else if (processedInvoices === 0) {
      newStatus = 'failed';
    } else {
      newStatus = 'partial';
    }
  } else if (processedInvoices > 0 || errorCount > 0) {
    newStatus = 'processing';
  }
  
  await doc.update({ 
    status: newStatus, 
    lastUpdatedAt: new Date() 
  });
};

const addInvoice = async (userId, packageId, invoiceData) => {
  const db = getFirestore();
  const invoices = PKG(db, userId).doc(packageId).collection('invoices');
  const ref = await invoices.add(invoiceData);
  return { id: ref.id, ...invoiceData };
};

const updateInvoice = async (userId, packageId, invoiceId, data) => {
  const db = getFirestore();
  const doc = PKG(db, userId).doc(packageId).collection('invoices').doc(invoiceId);
  await doc.update(data);
  
  // Invoice güncellendiğinde package status'unu da güncelle
  await updatePackageStatus(userId, packageId);
};

const listPackages = async (userId, { limit = 20, startAfter } = {}) => {
  const db = getFirestore();
  let q = PKG(db, userId).orderBy('createdAt', 'desc').limit(limit);
  if (startAfter) q = q.startAfter(startAfter);
  const snap = await q.get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

const getPackage = async (userId, packageId) => {
  const db = getFirestore();
  const doc = await PKG(db, userId).doc(packageId).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
};

const listInvoices = async (userId, packageId, { limit = 50, startAfter } = {}) => {
  const db = getFirestore();
  let q = PKG(db, userId).doc(packageId).collection('invoices').orderBy('uploadedAt', 'desc').limit(limit);
  if (startAfter) q = q.startAfter(startAfter);
  const snap = await q.get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

const getInvoice = async (userId, packageId, invoiceId) => {
    const db = getFirestore();
    const doc = await PKG(db, userId).doc(packageId).collection('invoices').doc(invoiceId).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() };
};

module.exports = {
  createPackage,
  updatePackage,
  incrementCounters,
  updatePackageStatus,
  addInvoice,
  updateInvoice,
  listPackages,
  getPackage,
  listInvoices,
  getInvoice,
};
