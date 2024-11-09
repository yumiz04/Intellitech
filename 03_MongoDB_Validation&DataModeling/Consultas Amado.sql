-- ------------------------------------------------------
-- Autores: Dana, Amado
-- Tema: Crear consultas para generar los archivos json
-- Fecha: 06 de noviembre del 2024
-- ------------------------------------------------------

-- ---------------------------------------------------
-- JSON for categorias
SELECT * FROM categorias;

SELECT
    id_categoria,
    nombre_categoria
FROM categorias
for JSON PATH;

-- ---------------------------------------------------
-- JSON for clientes
SELECT * FROM clientes;

SELECT
    C.id_cliente,
    C.nombre AS [nombre_cliente.primer_nombre],
    C.apellido_paterno AS [nombre_cliente.apellido_paterno],
    C.apellido_materno AS [nombre_cliente.apellido_materno],
    JSON_ARRAY(C.telefono) AS [contacto.telefono],
    C.correo AS [contacto.correo],
    C.rfc,
    C.nombre_empresa,

    D.id_direccion AS [direcciones.id_direccion], -- Agregar pais (a futuro)
    -- D.estado AS [direcciones.estado],
    -- D.municipio AS [direcciones.municipio],
    -- D.localidad AS [direcciones.localidad],
    -- D.calle AS [direcciones.calle],
    -- D.codigo_postal AS [direcciones.codigo_postal],
    -- D.descripcion_adicional AS [direcciones.descripcion_adicional],

    A.usuario AS [autenticaciones.usuario],
    A.contrasena AS [autenticaciones.contrasena]
  FROM clientes C
  JOIN direcciones D ON C.id_cliente = D.id_cliente
  JOIN autenticaciones A ON C.id_cliente = A.id_cliente
  FOR JSON PATH;

-- ---------------------------------------------------

SELECT * FROM direcciones;

SELECT
    D.id_direccion,
    D.estado,
    D.municipio,
    D.localidad,
    D.calle,
    D.codigo_postal,
    D.descripcion_adicional
FROM direcciones D
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for compras
SELECT * FROM compras;

SELECT 
    C.id_compra,
    C.fecha_compra,
    C.precio_compra,
    C.id_proveedor

FROM compras C
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for descuentos
SELECT * FROM descuentos;

SELECT
    id_descuento,
    descripcion,
    porcentaje_descuento,
    fecha_inicio,
    fecha_fin
FROM descuentos
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for pedidos
SELECT * FROM pedidos;

SELECT 
    P.id_pedido,
    P.fecha_pedido,
    P.total_pedido,
    P.descuento_total,
    P.total_general,
    P.id_estado_pedido,
    P.id_tiempo_llegada AS "id_tiempos_entrega",
    P.id_cliente
FROM pedidos P
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for resenas
SELECT * FROM resenas;

SELECT
    R.id_resena,
    R.fecha_resena,
    R.comentario,
    R.id_cliente,
    R.id_producto
FROM resenas R
FOR JSON PATH;