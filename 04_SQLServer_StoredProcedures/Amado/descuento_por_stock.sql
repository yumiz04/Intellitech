-- 1. Creaci�n de la Tabla auditorias_precios
-- Esta tabla permite llevar un registro hist�rico de las modificaciones de
-- precios, lo cual es �til para auditor�as y an�lisis posteriores.
CREATE TABLE auditorias_precios (
    id_auditoria INT IDENTITY(1,1) PRIMARY KEY, -- Identificador �nico para cada registro de auditor�a
    id_producto INT NOT NULL, -- Identificador del producto cuyo precio fue modificado
    nombre_producto NVARCHAR(100) NOT NULL, -- Nombre del producto
    modelo NVARCHAR(100) NULL, -- Modelo del producto (puede ser NULL si no se proporciona)
    precio_anterior DECIMAL(18, 2) NOT NULL, -- Precio del producto antes de la modificaci�n
    nuevo_precio DECIMAL(18, 2) NOT NULL, -- Nuevo precio del producto despu�s de la modificaci�n
    stock INT NOT NULL, -- Stock del producto en el momento de la modificaci�n
    fecha_modificacion DATETIME NOT NULL DEFAULT GETDATE(), -- Fecha y hora en que se realiz� la modificaci�n
    CONSTRAINT FK_auditorias_productos FOREIGN KEY (id_producto) REFERENCES productos(id_producto) -- Clave for�nea que referencia a la tabla productos
);

-- 2. Funci�n para Validar Categor�a
-- Esta funci�n verifica si una categor�a existe en la tabla categorias.
-- Devuelve 1 si la categor�a existe y 0 si no existe.
CREATE FUNCTION dbo.fn_validar_categoria (
    @CategoriaID INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @Existe BIT;

    -- Verificar si la categor�a existe
    IF EXISTS (SELECT 1 FROM categorias WHERE id_categoria = @CategoriaID)
    BEGIN
        SET @Existe = 1;
    END
    ELSE
    BEGIN
        SET @Existe = 0;
    END

    RETURN @Existe;
END;

-- 3. Procedimiento Almacenado 
CREATE PROC sp_actualizar_precios_descuento
    @CategoriaID INT,
    @PorcentajeDescuento DECIMAL(5, 2),
    @StockLimite INT
AS
BEGIN
    -- Validar par�metros de entrada
    IF @CategoriaID IS NULL OR @PorcentajeDescuento IS NULL OR @StockLimite IS NULL
    BEGIN
        ;THROW 50001, 'Los par�metros de entrada no pueden ser nulos.', 1;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Validar categor�a usando la funci�n
        IF dbo.fn_validar_categoria(@CategoriaID) = 0
        BEGIN
            PRINT 'La categor�a con ID ' + CAST(@CategoriaID AS NVARCHAR) + ' no se encuentra.';
            ;THROW 50003, 'La categor�a especificada no existe.', 1;
        END
        ELSE
        BEGIN
            DECLARE @CategoriaNombre NVARCHAR(100);
            SELECT @CategoriaNombre = nombre_categoria
            FROM categorias
            WHERE id_categoria = @CategoriaID;
            PRINT 'Categor�a encontrada: ' + @CategoriaNombre;
        END

        -- Capturar precios originales antes de la actualizaci�n
        DECLARE @PreciosOriginales TABLE (
            id_producto INT,
            nombre_producto NVARCHAR(100),
            modelo NVARCHAR(100),
            precio_anterior DECIMAL(18, 2),
            stock INT
        );

        INSERT INTO @PreciosOriginales (id_producto, nombre_producto, modelo, precio_anterior, stock)
        SELECT id_producto, nombre_producto, modelo, precio, stock
        FROM productos
        WHERE id_categoria = @CategoriaID AND stock < @StockLimite;

        -- Actualizar precios con descuento
        UPDATE p
        SET p.precio = p.precio - (p.precio * (@PorcentajeDescuento / 100))
        FROM productos p
        WHERE p.id_categoria = @CategoriaID AND p.stock < @StockLimite;

        -- Registrar en auditor�as
        INSERT INTO auditorias_precios (id_producto, nombre_producto, modelo, precio_anterior, nuevo_precio, stock, fecha_modificacion)
        SELECT 
            po.id_producto, 
            po.nombre_producto, 
            po.modelo, 
            po.precio_anterior, 
            po.precio_anterior - (po.precio_anterior * (@PorcentajeDescuento / 100)), 
            po.stock, 
            GETDATE()
        FROM @PreciosOriginales po;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        -- Lanzar el error original
        THROW;
    END CATCH
END;

-- 4. Trigger combinado para validar precios negativos y cantidades negativas en inventario
CREATE TRIGGER trg_validar_precios_inventario
ON productos
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Verificar que los nuevos precios no sean negativos
    IF EXISTS (SELECT 1 FROM inserted WHERE precio < 0)
    BEGIN
        -- Lanzar un error si se encuentra un precio negativo
        RAISERROR ('No se puede actualizar el precio a un valor negativo.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Verificar que el inventario no sea negativo
    IF EXISTS (SELECT 1 FROM inserted WHERE stock < 0)
    BEGIN
        -- Lanzar un error si se encuentra un inventario negativo
        RAISERROR ('No se puede actualizar el inventario a un valor negativo.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Si todas las validaciones son correctas, proceder con la actualizaci�n
    UPDATE p
    SET p.precio = i.precio,
        p.stock = i.stock
    FROM productos p
    INNER JOIN inserted i ON p.id_producto = i.id_producto;
END;

-- 5. Ejecuci�n del Procedimiento Almacenado
EXEC sp_actualizar_precios_descuento @CategoriaID = 2, @PorcentajeDescuento = 10, @StockLimite = 10;

-- Verificar productos y el hist�rico en la tabla de auditorias
select * from productos;
select * from auditorias_precios;
