-- Danna Geraldine Avila Garcia
-- --------------------------------------------------------------------------------------------------------------------------------------
-- Problema 2: Gestión de Pedidos con Validación de Stock
-- Objetivo: Diseñar un procedimiento que procese pedidos de clientes, verificando el stock antes de confirmar la compra. 
-- Si algún producto no tiene inventario suficiente, la transacción debe fallar.-- 1. Creación de la Función para Validar Pedido Existente

-- Función para validar si un pedido existe en la tabla 'pedidos'
CREATE FUNCTION dbo.fn_validar_pedido (
    @IDPedido INT -- Parametro que recibe el ID del pedido
)
RETURNS BIT -- Devuelve un valor 1 si existe o 0 si no
AS
BEGIN
    DECLARE @Existe BIT; -- Variable para almacenar si el pedido existe 

    -- Consulta para verificar si el pedido existe
    IF EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @IDPedido)
        SET @Existe = 1;  -- El pedido existe
    ELSE
        SET @Existe = 0;  -- El pedido no existe

    RETURN @Existe; -- Devuelve el resultado
END
GO


-- 2. Trigger para Prevenir Cantidades Negativas en Inventario
-- Trigger para validar inventario antes de una actualización en la tabla 'productos'
CREATE TRIGGER trg_validar_inventario
ON productos
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON; -- Evita mensajes adicionales de finalizacion de consulta

    -- Validar que las cantidades en el inventario no sean negativas
    IF EXISTS (SELECT 1 FROM inserted WHERE stock < 0) -- verifica  si algun registro tiene stock negativo
    BEGIN
        RAISERROR ('No se puede actualizar el inventario a un valor negativo.', 16, 1); -- Lanza el error
        ROLLBACK TRANSACTION; -- Cansela la transaccion
        RETURN;
    END

    -- Actualizar inventario si no hay errores
    UPDATE p
    SET p.stock = i.stock -- Actualiza el stock de producto
    FROM productos p
    INNER JOIN inserted i ON p.id_producto = i.id_producto; -- Combina con los datos de la tabla temporal 'inserted'
END
GO

-- 3. Creación de la Tabla estado del pedido
-- Tabla para almacenar los estados de los pedidos
CREATE TABLE estado_del_pedido (
    id_pedido INT PRIMARY KEY,  -- Clave primaria para identificar el pedido
    estado NVARCHAR(50) NOT NULL,  -- Estado del pedido (ej. "Confirmado", "Pendiente")
    fecha_actualizacion DATETIME NOT NULL,  -- Fecha y hora de la última actualización del estado
	FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido) ON DELETE CASCADE  -- Clave foránea a la tabla pedidos
);
GO

DROP table estado_del_pedido;
DROP PROCEDURE sp_gestionar_pedido;

-- 4. Procedimiento Almacenado para Gestión de Pedidos
CREATE PROCEDURE sp_gestionar_pedido
    @IDPedido INT, -- id del pedido a proceso 
    @NuevoEstado NVARCHAR(50) -- nuevo estado asignado al proceso
AS
BEGIN
    -- Validar parámetros de entrada
    IF @IDPedido IS NULL OR @NuevoEstado IS NULL -- verifica si los parametros son nulos
    BEGIN
        THROW 50001, 'Los parámetros de entrada no pueden ser nulos.', 1; -- Lanza un error
    END

    -- Iniciar transacción
    BEGIN TRANSACTION;

	 -- Declaración de variables y tablas temporales para almacenar errores y detalles procesados
    DECLARE @ErrorMensaje NVARCHAR(MAX) = '';
    DECLARE @DetallesErrores TABLE (
        id_producto INT,
        nombre_producto NVARCHAR(100),
        cantidad_solicitada INT,
        stock_disponible INT
    );
    DECLARE @DetallesProcesados TABLE (
        id_producto INT,
        nombre_producto NVARCHAR(100),
        cantidad_solicitada INT,
        cantidad_restante INT
    );

    BEGIN TRY
        -- Validar que el pedido exista
        IF NOT EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @IDPedido) -- Verifica la existencia del pedido
        BEGIN
            SET @ErrorMensaje = 'El pedido especificado no existe.';
            RAISERROR(@ErrorMensaje, 16, 1); -- Lanza un error si el pedido no existe
            RETURN;
        END

        -- Validar que todos los productos del pedido tengan suficiente stock
        IF EXISTS (
            SELECT dp.id_producto, dp.cantidad, p.stock
            FROM detalles_pedido dp
            INNER JOIN productos p ON dp.id_producto = p.id_producto
            WHERE dp.id_pedido = @IDPedido AND dp.cantidad > p.stock
        )
        BEGIN
			-- Si hay productos en el pedido donde la cantidad solicitada es mayor al stock disponible,
            -- el pedido no puede ser procesado. Se activa esta condición para manejar ese escenario.

            -- Almacenar detalles de los productos con problemas en la tabla temporal
            INSERT INTO @DetallesErrores (id_producto, nombre_producto, cantidad_solicitada, stock_disponible)
            SELECT dp.id_producto, p.nombre_producto, dp.cantidad, p.stock
            FROM detalles_pedido dp
            INNER JOIN productos p ON dp.id_producto = p.id_producto
            WHERE dp.id_pedido = @IDPedido AND dp.cantidad > p.stock;
			-- Se inserta en la tabla temporal @DetallesErrores los datos de los productos que tienen problemas
            -- de stock, como el ID del producto, su nombre, la cantidad solicitada y el stock actual disponible.

            SET @ErrorMensaje = 'No hay suficiente stock para uno o más productos del pedido.';
			-- Se define un mensaje de error que describe la situación.
            RAISERROR(@ErrorMensaje, 16, 1);
			 -- Se lanza el error para detener el procedimiento y notificar al usuario.
            RETURN;
        END

        -- Descontar del inventario las cantidades solicitadas y registrar los detalles procesados
        INSERT INTO @DetallesProcesados (id_producto, nombre_producto, cantidad_solicitada, cantidad_restante)
        SELECT dp.id_producto, p.nombre_producto, dp.cantidad, p.stock - dp.cantidad
        FROM detalles_pedido dp
        INNER JOIN productos p ON dp.id_producto = p.id_producto
        WHERE dp.id_pedido = @IDPedido;
		-- Si no hay problemas de stock, se registran los detalles del procesamiento de cada producto.
        -- Esto incluye el ID del producto, su nombre, la cantidad solicitada y el stock restante
        -- después de descontar la cantidad solicitada.

        UPDATE p
        SET p.stock = p.stock - dp.cantidad
        FROM productos p
        INNER JOIN detalles_pedido dp ON p.id_producto = dp.id_producto
        WHERE dp.id_pedido = @IDPedido;
		-- Se actualiza el stock de los productos en la tabla "productos", descontando la cantidad
        -- solicitada en el pedido. Esto asegura que el inventario refleje las cantidades correctas.

        -- Registrar o actualizar el estado del pedido
        IF EXISTS (SELECT 1 FROM estado_del_pedido WHERE id_pedido = @IDPedido)
        BEGIN
            UPDATE estado_del_pedido
            SET estado = @NuevoEstado, fecha_actualizacion = GETDATE()
            WHERE id_pedido = @IDPedido;
			 -- Si ya existe un registro en la tabla "estado_del_pedido" para este pedido, se actualiza
            -- el estado y la fecha de última actualización.

        END
        ELSE
        BEGIN
            INSERT INTO estado_del_pedido (id_pedido, estado, fecha_actualizacion)
            VALUES (@IDPedido, @NuevoEstado, GETDATE());
			-- Si no existe un registro para el pedido, se crea uno nuevo con el estado actualizado
            -- y la fecha actual.

        END

        -- Confirmar la transacción
        COMMIT TRANSACTION;

        -- Confirmación del pedido
        PRINT 'El pedido fue procesado exitosamente y el inventario se actualizó.';
        SELECT 
            @IDPedido AS id_pedido,
            @NuevoEstado AS estado_actualizado,
            dp.id_producto,
            dp.nombre_producto,
            dp.cantidad_solicitada,
            dp.cantidad_restante
        FROM @DetallesProcesados dp;
	    -- Se debuelven los datalles del proceso id del pedido el estado actualizado y los procesos de cantidad solicitada y el stock
    END TRY

    BEGIN CATCH
        -- Revertir la transacción en caso de error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Re-lanzar el error original
        THROW;
    END CATCH

    -- Mostrar errores o rechazos del pedido
    IF @ErrorMensaje <> ''
    BEGIN
        PRINT 'No se pudo procesar el pedido debido a errores.';
        SELECT 
            @IDPedido AS id_pedido,
            @ErrorMensaje AS mensaje_error,
            de.id_producto,
            de.nombre_producto,
            de.cantidad_solicitada,
            de.stock_disponible
        FROM @DetallesErrores de;
		-- Se devuelven los detalles del producto con problemas el id pedido el mensaje de errory la informacion de los problemas
		-- de los productos de stock
    END
END;
GO


-- Consultar los estados de los pedidos
SELECT * FROM estado_del_pedido;

-- 5. Ejecución del procedimiento
EXEC sp_gestionar_pedido @IDPedido = 1, @NuevoEstado = 'Confirmado';
EXEC sp_gestionar_pedido @IDPedido = 2, @NuevoEstado = 'Pendiente';
EXEC sp_gestionar_pedido @IDPedido = 3, @NuevoEstado = 'Confirmado';

-- Verificar el estado de un pedido específico
SELECT * FROM estado_del_pedido WHERE id_pedido = 1;






