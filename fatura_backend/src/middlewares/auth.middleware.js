const jwt = require('jsonwebtoken');

const protect = (req, res, next) => {
    let token;
    
    // JWT_SECRET kontrolü - Production'da zorunlu
    if (!process.env.JWT_SECRET) {
        console.error('⚠️ JWT_SECRET environment variable tanımlı değil!');
        return res.status(500).json({ message: 'Server configuration error' });
    }
    
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
        try {
            // Get token from header
            token = req.headers.authorization.split(' ')[1];

            // Verify token
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            
            // Attach user to the request object
            req.user = decoded; 
            
            return next();
        } catch (error) {
            console.error(error);
            return res.status(401).json({ message: 'Not authorized, token failed' });
        }
    }

    // Token yoksa
    return res.status(401).json({ message: 'Not authorized, no token' });
};

module.exports = { protect };
