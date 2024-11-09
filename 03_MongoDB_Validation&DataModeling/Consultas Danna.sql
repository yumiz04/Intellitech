-- ------------------------------------------------------
-- Autores: Dana, Amado
-- Tema: Crear consultas para generar los archivos json
-- Fecha: 06 de noviembre del 2024
-- ------------------------------------------------------

-- ---------------------------------------------------

-- ---------------------------------------------------
-- JSON for margenes_ganancia
SELECT * FROM margenes_ganancia;

SELECT 
    id_margen_ganancia AS "id_margen",
    margen_ganancia AS "porcentaje"
FROM margenes_ganancia
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for tipos_devolucion
SELECT * FROM tipos_devolucion;

SELECT 
    id_tipo_devolucion,
    descripcion
FROM tipos_devolucion
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for devoluciones
SELECT * FROM devoluciones;

SELECT 
    D.id_devolucion,
    D.fecha_devolucion,
    D.cantidad,
    D.id_tipo_devolucion,
    D.id_pedido
FROM devoluciones D
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for proveedores
SELECT * FROM proveedores;
SELECT * FROM direcciones_proveedores;

SELECT 
    P.id_proveedor,
    
    P.nombre_proveedor AS [nombre_proveedor.primer_nombre],
    P.apellido_paterno AS [nombre_proveedor.apellido_paterno],
    P.apellido_materno AS [nombre_proveedor.apellido_materno],
    
    JSON_ARRAY(P.telefono_proveedor) AS [contacto.telefono],
    P.correo_proveedor AS [contacto.correo],
    
    D.id_direccion_proveedor AS [direcciones_proveedores.id_direccion], -- Agregar pais (a futuro)
    D.estado AS [direcciones_proveedores.estado],
    D.municipio AS [direcciones_proveedores.municipio],
    D.localidad AS [direcciones_proveedores.localidad],
    D.calle AS [direcciones_proveedores.calle],
    D.codigo_postal AS [direcciones_proveedores.codigo_postal],
    D.descripcion_adicional AS [direcciones_proveedores.descripcion_adicional]
    
FROM proveedores P
JOIN direcciones_proveedores D ON P.id_proveedor = D.id_proveedor
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for proveedores
SELECT * FROM proveedores;

SELECT 
    P.id_proveedor,
    P.nombre_proveedor AS [nombre_proveedor.primer_nombre],
    P.apellido_paterno AS [nombre_proveedor.apellido_paterno],
    P.apellido_materno AS [nombre_proveedor.apellido_materno],
    JSON_ARRAY(P.telefono_proveedor) AS [contacto.telefono],
    P.correo_proveedor AS [contacto.correo],
    P.rfc,
    P.nombre_empresa,

    DP.id_direccion_proveedor AS "id_direccion"
FROM proveedores P
JOIN direcciones_proveedores DP ON DP.id_proveedor = P.id_proveedor
FOR JSON PATH;

-- ---------------------------------------------------

SELECT * FROM direcciones_proveedores;


SELECT 
    DP.id_direccion_proveedor AS "id_direccion",
    DP.estado,
    DP.municipio,
    DP.localidad,
    DP.calle,
    DP.codigo_postal,
    DP.descripcion_adicional
FROM direcciones_proveedores DP
FOR JSON PATH;

-- ---------------------------------------------------
-- JSON for productos
SELECT * FROM productos;

SELECT 
    P.id_producto,
    P.nombre_producto,
    P.modelo,
    P.precio,
    P.stock,
    P.descripcion,
    P.estado_producto,
    P.id_categoria
FROM productos P
FOR JSON PATH;

