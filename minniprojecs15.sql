CREATE DATABASE social_network;
USE social_network;

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FULLTEXT(content)
);

CREATE TABLE comments (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id)
);

CREATE TABLE likes (
    like_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, post_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id)
);

CREATE TABLE friends (
    friendship_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    friend_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (friend_id) REFERENCES users(user_id)
);

CREATE TABLE post_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    post_content TEXT NOT NULL,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, password, email) VALUES
('user1', 'pass123', 'user1@email.com'),
('user2', 'pass123', 'user2@email.com'),
('user3', 'pass123', 'user3@email.com');

INSERT INTO posts (user_id, content) VALUES
(1, 'Hello Rikkei Education 1'),
(2, 'Hello Rikkei Education 2'),
(3, 'Hello Rikkei Education 3');

INSERT INTO comments (user_id, post_id, content) VALUES
(2, 1, 'Comment 1'),
(3, 1, 'Comment 2'),
(1, 2, 'Comment 3');

INSERT INTO likes (user_id, post_id) VALUES
(2, 1),
(3, 1),
(1, 2);

INSERT INTO friends (user_id, friend_id) VALUES
(1, 2),
(2, 3);

CREATE VIEW view_user_info AS
SELECT user_id, username, email, created_at
FROM users;

DELIMITER //

CREATE PROCEDURE sp_add_user(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_email VARCHAR(100)
)
BEGIN
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username OR email = p_email) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Username or Email already exists';
    ELSE
        INSERT INTO users (username, password, email)
        VALUES (p_username, p_password, p_email);
    END IF;
END //

CREATE TRIGGER tg_after_like_insert
AFTER INSERT ON likes
FOR EACH ROW
BEGIN
    UPDATE posts
    SET like_count = like_count + 1
    WHERE post_id = NEW.post_id;
END //

CREATE TRIGGER tg_after_like_delete
AFTER DELETE ON likes
FOR EACH ROW
BEGIN
    UPDATE posts
    SET like_count = GREATEST(like_count - 1, 0)
    WHERE post_id = OLD.post_id;
END //

CREATE TRIGGER tg_after_comment_insert
AFTER INSERT ON comments
FOR EACH ROW
BEGIN
    UPDATE posts
    SET comment_count = comment_count + 1
    WHERE post_id = NEW.post_id;
END //

CREATE TRIGGER tg_after_comment_delete
AFTER DELETE ON comments
FOR EACH ROW
BEGIN
    UPDATE posts
    SET comment_count = GREATEST(comment_count - 1, 0)
    WHERE post_id = OLD.post_id;
END //

CREATE PROCEDURE sp_user_activity_report()
BEGIN
    SELECT
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id) AS total_posts,
        COUNT(DISTINCT l.like_id) AS total_likes,
        COUNT(DISTINCT c.comment_id) AS total_comments
    FROM users u
    LEFT JOIN posts p ON u.user_id = p.user_id
    LEFT JOIN likes l ON u.user_id = l.user_id
    LEFT JOIN comments c ON u.user_id = c.user_id
    GROUP BY u.user_id, u.username;
END //

CREATE PROCEDURE sp_delete_user(
    IN p_user_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    DELETE FROM likes WHERE user_id = p_user_id;
    DELETE FROM likes WHERE post_id IN (SELECT post_id FROM posts WHERE user_id = p_user_id);
    
    DELETE FROM comments WHERE user_id = p_user_id;
    DELETE FROM comments WHERE post_id IN (SELECT post_id FROM posts WHERE user_id = p_user_id);
    
    DELETE FROM friends WHERE user_id = p_user_id OR friend_id = p_user_id;
    
    DELETE FROM posts WHERE user_id = p_user_id;
    
    DELETE FROM users WHERE user_id = p_user_id;

    COMMIT;
END //

CREATE TRIGGER tg_before_friend_insert
BEFORE INSERT ON friends
FOR EACH ROW
BEGIN
    IF NEW.user_id = NEW.friend_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot friend yourself';
    END IF;

    IF EXISTS (SELECT 1 FROM friends WHERE user_id = NEW.user_id AND friend_id = NEW.friend_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Friendship already exists';
    END IF;

    IF EXISTS (SELECT 1 FROM friends WHERE user_id = NEW.friend_id AND friend_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Reverse invitation already exists';
    END IF;
END //

CREATE TRIGGER tg_after_post_delete
AFTER DELETE ON posts
FOR EACH ROW
BEGIN
    INSERT INTO post_logs (post_id, post_content, deleted_at)
    VALUES (OLD.post_id, OLD.content, NOW());
END //

DELIMITER ;