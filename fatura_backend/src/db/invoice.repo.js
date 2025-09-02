const admin = require('firebase-admin');

// Lazy loading: Firebase'i sadece gerektiğinde başlat
const getFirestore = () => {
  if (!admin.apps.length) {
    throw new Error('Firebase Admin SDK not initialized. Please call initializeFirebase() first.');
  }
  return admin.firestore();
};

const saveInvoice = async (invoiceData) => {
    try {
        const db = getFirestore();
        const { userId, ...invoiceDataWithoutUserId } = invoiceData;
        const sanitized = Object.fromEntries(
            Object.entries(invoiceDataWithoutUserId || {}).filter(([_, v]) => v !== undefined)
        );
        
        // app_users/{userId}/invoices alt-koleksiyonuna kaydet
        const userInvoicesCollection = db.collection('app_users').doc(userId).collection('invoices');
        const docRef = await userInvoicesCollection.add(sanitized);
        
        console.log(`Invoice saved to Firestore: app_users/${userId}/invoices/${docRef.id}`);
        return { id: docRef.id, userId, ...sanitized };
    } catch (error) {
        console.error('Error saving invoice to Firestore:', error);
        throw new Error('Could not save invoice data.');
    }
};

const updateInvoice = async (userId, invoiceId, updateData) => {
    try {
        const db = getFirestore();
        const userInvoicesCollection = db.collection('app_users').doc(userId).collection('invoices');
        const sanitized = Object.fromEntries(
            Object.entries(updateData || {}).filter(([_, v]) => v !== undefined)
        );
        await userInvoicesCollection.doc(invoiceId).update(sanitized);
        
        console.log(`Invoice updated in Firestore: app_users/${userId}/invoices/${invoiceId}`);
        return { id: invoiceId, userId, ...updateData };
    } catch (error) {
        console.error('Error updating invoice in Firestore:', error);
        throw new Error('Could not update invoice data.');
    }
};

const getInvoicesByUserId = async (userId) => {
    try {
        const db = getFirestore();
        const userInvoicesCollection = db.collection('app_users').doc(userId).collection('invoices');
        const snapshot = await userInvoicesCollection
            .orderBy('uploadedAt', 'desc')
            .get();
            
        if (snapshot.empty) {
            return [];
        }
        
        const invoices = [];
        snapshot.forEach(doc => {
            invoices.push({ id: doc.id, userId, ...doc.data() });
        });

        return invoices;
    } catch (error) {
        console.error('Error getting invoices from Firestore:', error);
        throw new Error('Could not retrieve invoices.');
    }
};

const getInvoiceById = async (userId, invoiceId) => {
    try {
        const db = getFirestore();
        const userInvoicesCollection = db.collection('app_users').doc(userId).collection('invoices');
        const doc = await userInvoicesCollection.doc(invoiceId).get();
        
        if (!doc.exists) {
            return null;
        }
        
        return { id: doc.id, userId, ...doc.data() };
    } catch (error) {
        console.error('Error getting invoice from Firestore:', error);
        throw new Error('Could not retrieve invoice.');
    }
};

module.exports = {
    saveInvoice,
    updateInvoice,
    getInvoicesByUserId,
    getInvoiceById
};
