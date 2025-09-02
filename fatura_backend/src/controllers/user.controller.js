const admin = require('firebase-admin');

// Kullanıcı bilgilerini getir
const getUserProfile = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        
        console.log('🔍 JWT Token içeriği:', req.user);
        console.log('🔍 Aranan User ID:', userId);

        if (!userId) {
            return res.status(401).json({
                success: false,
                message: 'Kullanıcı kimliği bulunamadı'
            });
        }

        // Önce Firestore'dan kullanıcı bilgilerini al
        let userProfile = {};
        let firestoreName = null;
        
        try {
            const userDoc = await admin.firestore().collection('app_users').doc(userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                firestoreName = userData?.name;
                console.log('✅ Firestore\'dan kullanıcı adı alındı:', firestoreName);
                
                // Password auth kullanıcısı için Firestore'dan bilgileri al
                userProfile = {
                    uid: userId,
                    email: userData?.email,
                    displayName: userData?.name,
                    photoURL: null,
                    emailVerified: false,
                    creationTime: userData?.createdAt?.toDate?.() || userData?.createdAt,
                    lastSignInTime: userData?.lastLoginAt?.toDate?.() || userData?.lastLoginAt,
                    name: firestoreName
                };
            }
        } catch (firestoreError) {
            console.log('⚠️ Firestore hatası (kullanıcı adı alınamadı):', firestoreError.message);
        }

        // Eğer Firestore'da bulunamadıysa Firebase Auth'dan dene
        if (!userProfile.uid) {
            try {
                const userRecord = await admin.auth().getUser(userId);
                userProfile = {
                    uid: userRecord.uid,
                    email: userRecord.email,
                    displayName: userRecord.displayName,
                    photoURL: userRecord.photoURL,
                    emailVerified: userRecord.emailVerified,
                    creationTime: userRecord.metadata.creationTime,
                    lastSignInTime: userRecord.metadata.lastSignInTime,
                    name: firestoreName || userRecord.displayName
                };
            } catch (firebaseError) {
                console.log('⚠️ Firebase Auth hatası:', firebaseError.message);
                // Sadece Firestore bilgileriyle devam et
            }
        }

        console.log('✅ Kullanıcı profili başarıyla alındı:', {
            uid: userProfile.uid,
            email: userProfile.email,
            name: userProfile.name,
            displayName: userProfile.displayName
        });

        res.status(200).json({
            success: true,
            user: userProfile
        });

    } catch (error) {
        console.error('Error in getUserProfile controller:', error.message);
        res.status(500).json({
            success: false,
            message: 'Kullanıcı bilgileri alınamadı',
            error: error.message
        });
    }
};

// Kullanıcı profilini güncelle
const updateUserProfile = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { displayName, photoURL } = req.body;

        if (!userId) {
            return res.status(401).json({
                success: false,
                message: 'Kullanıcı kimliği bulunamadı'
            });
        }

        // Firebase Auth'da kullanıcı bilgilerini güncelle
        await admin.auth().updateUser(userId, {
            displayName: displayName || undefined,
            photoURL: photoURL || undefined
        });

        res.status(200).json({
            success: true,
            message: 'Kullanıcı profili başarıyla güncellendi'
        });

    } catch (error) {
        console.error('Error in updateUserProfile controller:', error.message);
        res.status(500).json({
            success: false,
            message: 'Kullanıcı profili güncellenemedi',
            error: error.message
        });
    }
};

module.exports = {
    getUserProfile,
    updateUserProfile
};
