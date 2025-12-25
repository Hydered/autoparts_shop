-- ===========================================
-- Автозапчасти - База данных для SQL Server
-- ===========================================

USE master;
GO

-- Создание базы данных
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'AutoPartsShop')
BEGIN
    CREATE DATABASE AutoPartsShop
    COLLATE Cyrillic_General_CI_AS;
END
GO

USE AutoPartsShop;
GO

-- ===========================================
-- 1. Таблица категорий товаров
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Categories' AND xtype='U')
BEGIN
    CREATE TABLE Categories (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(100) NOT NULL UNIQUE,
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        UpdatedAt DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- ===========================================
-- 2. Таблица товаров
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Products' AND xtype='U')
BEGIN
    CREATE TABLE Products (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(200) NOT NULL,
        Description NVARCHAR(MAX),
        Price DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
        ImageUrl NVARCHAR(500),
        CategoryId INT NOT NULL,
        Sku NVARCHAR(50) UNIQUE,
        MinQuantity INT DEFAULT 5 CHECK (MinQuantity >= 0),
        Stock INT DEFAULT 0 CHECK (Stock >= 0),
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        UpdatedAt DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (CategoryId) REFERENCES Categories(Id) ON DELETE CASCADE
    );
END
GO

-- ===========================================
-- 3. Таблица характеристик (справочник)
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Characteristics' AND xtype='U')
BEGIN
    CREATE TABLE Characteristics (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(100) NOT NULL,
        Unit NVARCHAR(20), -- ед. измерения (кг, мм, Вт и т.д.)
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        CONSTRAINT UQ_Characteristics_Name_Unit UNIQUE (Name, Unit)
    );
END
GO

-- ===========================================
-- 4. Таблица связи товаров с характеристиками
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ProductCharacteristics' AND xtype='U')
BEGIN
    CREATE TABLE ProductCharacteristics (
        ProductId INT NOT NULL,
        CharacteristicId INT NOT NULL,
        Value NVARCHAR(200) NOT NULL,
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        PRIMARY KEY (ProductId, CharacteristicId),
        FOREIGN KEY (ProductId) REFERENCES Products(Id) ON DELETE CASCADE,
        FOREIGN KEY (CharacteristicId) REFERENCES Characteristics(Id) ON DELETE CASCADE
    );
END
GO

-- ===========================================
-- 5. Таблица пользователей
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
BEGIN
    CREATE TABLE Users (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        FullName NVARCHAR(200) NOT NULL,
        Phone NVARCHAR(20) NOT NULL,
        Address NVARCHAR(500) NOT NULL,
        Email NVARCHAR(100) NOT NULL UNIQUE,
        PasswordHash NVARCHAR(255) NOT NULL,
        Role NVARCHAR(20) NOT NULL DEFAULT 'client' CHECK (Role IN ('admin', 'client')),
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        UpdatedAt DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- ===========================================
-- 6. Таблица продаж
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Sales' AND xtype='U')
BEGIN
    CREATE TABLE Sales (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        UserId INT NOT NULL,
        Status NVARCHAR(20) DEFAULT 'completed' CHECK (Status IN ('pending', 'completed', 'cancelled')),
        OrderNumber NVARCHAR(50) UNIQUE,
        TotalPrice DECIMAL(10,2),
        Notes NVARCHAR(MAX),
        ClientDeletedHistory BIT DEFAULT 0, -- Мягкое удаление для клиентов
        FOREIGN KEY (UserId) REFERENCES Users(Id)
    );
END
GO

-- ===========================================
-- 7. Таблица позиций продаж
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='SaleItems' AND xtype='U')
BEGIN
    CREATE TABLE SaleItems (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        SaleId INT NOT NULL,
        ProductId INT NOT NULL,
        Quantity INT NOT NULL CHECK (Quantity > 0),
        Price DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (SaleId) REFERENCES Sales(Id) ON DELETE CASCADE,
        FOREIGN KEY (ProductId) REFERENCES Products(Id)
    );
END
GO

-- ===========================================
-- 8. Таблица корзины пользователей
-- ===========================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='CartItems' AND xtype='U')
BEGIN
    CREATE TABLE CartItems (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT, -- NULL для гостей
        ProductId INT NOT NULL,
        Quantity INT NOT NULL CHECK (Quantity > 0),
        CreatedAt DATETIME2 DEFAULT GETDATE(),
        FOREIGN KEY (ProductId) REFERENCES Products(Id) ON DELETE CASCADE
    );
END
GO

-- ===========================================
-- ИНДЕКСЫ для оптимизации производительности
-- ===========================================

-- Индексы для Products
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_CategoryId')
    CREATE INDEX IX_Products_CategoryId ON Products(CategoryId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_Sku')
    CREATE INDEX IX_Products_Sku ON Products(Sku);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_Name')
    CREATE INDEX IX_Products_Name ON Products(Name);

-- Индексы для Sales
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Sales_CreatedAt')
    CREATE INDEX IX_Sales_CreatedAt ON Sales(CreatedAt);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Sales_UserId')
    CREATE INDEX IX_Sales_UserId ON Sales(UserId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Sales_OrderNumber')
    CREATE INDEX IX_Sales_OrderNumber ON Sales(OrderNumber);

-- Индексы для SaleItems
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SaleItems_SaleId')
    CREATE INDEX IX_SaleItems_SaleId ON SaleItems(SaleId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SaleItems_ProductId')
    CREATE INDEX IX_SaleItems_ProductId ON SaleItems(ProductId);

-- Индексы для ProductCharacteristics
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ProductCharacteristics_ProductId')
    CREATE INDEX IX_ProductCharacteristics_ProductId ON ProductCharacteristics(ProductId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ProductCharacteristics_CharacteristicId')
    CREATE INDEX IX_ProductCharacteristics_CharacteristicId ON ProductCharacteristics(CharacteristicId);

-- Индексы для Characteristics
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Characteristics_Name_Unit')
    CREATE INDEX IX_Characteristics_Name_Unit ON Characteristics(Name, Unit);

-- Индексы для CartItems
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CartItems_UserId')
    CREATE INDEX IX_CartItems_UserId ON CartItems(UserId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CartItems_ProductId')
    CREATE INDEX IX_CartItems_ProductId ON CartItems(ProductId);

-- ===========================================
-- ЗАПОЛНЕНИЕ ТЕСТОВЫМИ ДАННЫМИ
-- ===========================================

-- Создание администратора
IF NOT EXISTS (SELECT * FROM Users WHERE Email = 'admin@admin.ru')
BEGIN
    INSERT INTO Users (FullName, Phone, Address, Email, PasswordHash, Role)
    VALUES ('Администратор', '-', '-', 'admin@admin.ru', 'admin', 'admin');
END
GO

-- Заполнение категорий
IF NOT EXISTS (SELECT * FROM Categories)
BEGIN
    INSERT INTO Categories (Name) VALUES
    ('Двигатель'),
    ('Трансмиссия'),
    ('Ходовая часть'),
    ('Электрика'),
    ('Кузов'),
    ('Выхлопная система'),
    ('Тормозная система'),
    ('Система охлаждения'),
    ('Фильтры'),
    ('Расходники');
END
GO

-- Заполнение характеристик
IF NOT EXISTS (SELECT * FROM Characteristics)
BEGIN
    INSERT INTO Characteristics (Name, Unit) VALUES
    -- Размеры и вес
    ('Вес', 'кг'),
    ('Длина', 'мм'),
    ('Ширина', 'мм'),
    ('Высота', 'мм'),
    ('Диаметр', 'мм'),
    ('Толщина', 'мм'),
    ('Внутренний диаметр', 'мм'),
    ('Наружный диаметр', 'мм'),

    -- Электрика
    ('Напряжение', 'В'),
    ('Ток', 'А'),
    ('Мощность', 'Вт'),
    ('Сопротивление', 'Ом'),

    -- Материалы
    ('Материал', NULL),
    ('Цвет', NULL),
    ('Марка стали', NULL),
    ('Тип резьбы', NULL),

    -- Технические параметры
    ('Объем', 'л'),
    ('Вместимость', 'л'),
    ('Давление', 'атм'),
    ('Температура', '°C'),
    ('Допустимая нагрузка', 'кг'),
    ('Срок службы', 'лет'),
    ('Гарантия', 'мес'),
    ('Количество', 'шт'),
    ('Шаг резьбы', 'мм'),
    ('Класс прочности', NULL),
    ('Рабочая температура', '°C');
END
GO

-- ===========================================
-- ПОЛЕЗНЫЕ ЗАПРОСЫ ДЛЯ АНАЛИТИКИ
-- ===========================================

-- 1. Топ-5 самых продаваемых товаров за последний месяц
/*
SELECT TOP 5
    p.Name as ProductName,
    p.Sku,
    SUM(si.Quantity) as TotalSold,
    SUM(si.Quantity * si.Price) as TotalRevenue
FROM Products p
JOIN SaleItems si ON p.Id = si.ProductId
JOIN Sales s ON si.SaleId = s.Id
WHERE s.CreatedAt >= DATEADD(MONTH, -1, GETDATE())
    AND s.Status = 'completed'
GROUP BY p.Id, p.Name, p.Sku
ORDER BY TotalSold DESC;
*/

-- 2. Товары с низким запасом
/*
SELECT
    p.Name,
    p.Sku,
    p.Stock as CurrentStock,
    p.MinQuantity,
    c.Name as CategoryName
FROM Products p
JOIN Categories c ON p.CategoryId = c.Id
WHERE p.Stock <= p.MinQuantity
ORDER BY p.Stock ASC;
*/

-- 3. Ежедневные продажи за последний месяц
/*
SELECT
    CAST(s.CreatedAt AS DATE) as SaleDate,
    COUNT(DISTINCT s.Id) as OrdersCount,
    SUM(s.TotalPrice) as TotalRevenue,
    SUM(si.Quantity) as ItemsSold
FROM Sales s
JOIN SaleItems si ON s.Id = si.SaleId
WHERE s.CreatedAt >= DATEADD(MONTH, -1, GETDATE())
    AND s.Status = 'completed'
GROUP BY CAST(s.CreatedAt AS DATE)
ORDER BY SaleDate DESC;
*/

-- 4. Статистика по категориям товаров
/*
SELECT
    c.Name as CategoryName,
    COUNT(p.Id) as ProductsCount,
    SUM(p.Stock) as TotalStock,
    AVG(p.Price) as AvgPrice,
    MIN(p.Price) as MinPrice,
    MAX(p.Price) as MaxPrice
FROM Categories c
LEFT JOIN Products p ON c.Id = p.CategoryId
GROUP BY c.Id, c.Name
ORDER BY ProductsCount DESC;
*/

-- 5. Активные пользователи (совершали покупки за последний месяц)
/*
SELECT DISTINCT
    u.FullName,
    u.Email,
    u.Phone,
    COUNT(s.Id) as OrdersCount,
    SUM(s.TotalPrice) as TotalSpent,
    MAX(s.CreatedAt) as LastOrderDate
FROM Users u
JOIN Sales s ON u.Id = s.UserId
WHERE s.CreatedAt >= DATEADD(MONTH, -1, GETDATE())
    AND s.Status = 'completed'
GROUP BY u.Id, u.FullName, u.Email, u.Phone
ORDER BY TotalSpent DESC;
*/

-- ===========================================
-- ТРИГГЕРЫ для автоматического обновления UpdatedAt
-- ===========================================

-- Триггер для Products
IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_Products_UpdateUpdatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER TR_Products_UpdateUpdatedAt
    ON Products
    AFTER UPDATE
    AS
    BEGIN
        UPDATE Products
        SET UpdatedAt = GETDATE()
        FROM Products p
        INNER JOIN inserted i ON p.Id = i.Id;
    END
    ');
END
GO

-- Триггер для Users
IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_Users_UpdateUpdatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER TR_Users_UpdateUpdatedAt
    ON Users
    AFTER UPDATE
    AS
    BEGIN
        UPDATE Users
        SET UpdatedAt = GETDATE()
        FROM Users u
        INNER JOIN inserted i ON u.Id = i.Id;
    END
    ');
END
GO

-- Триггер для Categories
IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_Categories_UpdateUpdatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER TR_Categories_UpdateUpdatedAt
    ON Categories
    AFTER UPDATE
    AS
    BEGIN
        UPDATE Categories
        SET UpdatedAt = GETDATE()
        FROM Categories c
        INNER JOIN inserted i ON c.Id = i.Id;
    END
    ');
END
GO

PRINT 'База данных AutoPartsShop успешно создана и настроена!';
GO
