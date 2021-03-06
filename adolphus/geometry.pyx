"""\
Geometry module. Contains point (vector) and pose transformation classes, and
geometric descriptor functions for features.

@author: Aaron Mavrinac
@organization: University of Windsor
@contact: mavrin1@uwindsor.ca
@license: GPL-3
"""

from math import pi, sqrt, sin, cos, asin, acos, atan2, copysign
from random import uniform, gauss
from functools import reduce
from cpython cimport bool


class Angle(float):
    """\
    Angle class. All operations are modulo 2S{pi}.
    """
    def __new__(cls, arg=0.0, unit='rad'):
        if unit == 'deg':
            arg *= pi / 180.0
        return float.__new__(cls, float(arg) % (2 * pi))

    def __add__(self, other):
        return Angle(float(self) + float(other))

    def __sub__(self, other):
        return Angle(float(self) - float(other))

    def __neg__(self):
        return Angle(-float(self))


cdef class Point:
    """\
    3D point (vector) class.

    Note that the hash and equality functions for points intentionally collide
    on points which are very close to each other (no greater than 1e-4 in any
    dimension) to allow for identity despite small errors, important for point
    caching and other coverage functionality.
    """
    def __cinit__(self, x, y, z, *args):
        """\
        Constructor.
        """
        self.x = x
        self.y = y
        self.z = z

    def __hash__(self):
        return hash(repr(self))

    def __reduce__(self):
        return (Point, (self.x, self.y, self.z))

    def __getitem__(self, i):
        return (self.x, self.y, self.z).__getitem__(i)

    def __richcmp__(self, Point p, int t):
        eq = abs(self.x - p.x) < 1e-4 and \
             abs(self.y - p.y) < 1e-4 and \
             abs(self.z - p.z) < 1e-4
        if t == 2:
            return eq
        if t == 3:
            return not eq

    cpdef Point _add(self, Point p):
        return Point(self.x + p.x, self.y + p.y, self.z + p.z)

    def __add__(self, Point p):
        """\
        Vector addition.

        @param p: The operand vector.
        @type p: L{Point}
        @return: Result vector.
        @rtype: L{Point}
        """
        return self._add(p)

    cpdef Point _sub(self, Point p):
        return Point(self.x - p.x, self.y - p.y, self.z - p.z)

    def __sub__(self, Point p):
        """\
        Vector subtraction.

        @param p: The operand vector.
        @type p: L{Point}
        @return: Result vector.
        @rtype: L{Point}
        """
        return self._sub(p)

    cpdef Point _mul(self, double s):
        return Point(self.x * s, self.y * s, self.z * s)

    def __mul__(self, double s):
        """\
        Scalar multiplication.

        @param s: The operand scalar.
        @type s: C{float}
        @return: Result vector.
        @rtype: L{Point}
        """
        return self._mul(s)

    cpdef Point _div(self, double s):
        return Point(self.x / s, self.y / s, self.z / s)

    def __div__(self, double s):
        """\
        Scalar division.

        @param s: The scalar divisor.
        @type s: C{float}
        @return: Result vector.
        @rtype: L{Point}
        """
        return self._div(s)

    cpdef Point _neg(self):
        return Point(-self.x, -self.y, -self.z)

    def __neg__(self):
        """\
        Negation.

        @return: Result vector.
        @rtype: L{Point}
        """
        return self._neg()

    def __repr__(self):
        """\
        Canonical string representation.

        @return: Canonical string representation.
        @rtype: C{str}
        """
        return '%s(%.4f, %.4f, %.4f)' % (type(self).__name__,
            self.x, self.y, self.z)

    def __str__(self):
        """\
        String representation, displays in a tuple format.

        @return: Vector string.
        @rtype: C{str}
        """
        return '(%.4f, %.4f, %.4f)' % (self.x, self.y, self.z)

    cpdef double dot(self, Point p):
        """\
        Dot product.

        @param p: The operand vector.
        @type p: L{Point}
        @return: Dot product.
        @rtype: C{float}
        """
        return self.x * p.x + self.y * p.y + self.z * p.z

    cpdef Point cross(self, Point p):
        """\
        Cross product.

        @param p: The operand vector.
        @type p: L{Point}
        @return: Cross product vector.
        @rtype: L{Point}
        """
        return Point(self.y * p.z - self.z * p.y,
                     self.z * p.x - self.x * p.z,
                     self.x * p.y - self.y * p.x)

    cpdef double cross_2d(self, Point p):
        """\
        Two dimensional cross product.

        @param p: The operand vector.
        @type p: L{Point}
        @return: two dimensional cross product.
        @rtype: L{Point}
        """
        return self.x * p.y - self.y * p.x

    cpdef double magnitude(self):
        """\
        Magnitude of this vector.

        @rtype: C{float}
        """
        if self._magnitude_c:
            return self._magnitude
        else:
            self._magnitude = sqrt(self.x ** 2 + self.y ** 2 + self.z ** 2)
            self._magnitude_c = True
            return self._magnitude

    cpdef Point unit(self):
        """\
        Unit vector in the direction of this vector.

        @rtype: L{Point}
        """
        cdef double m
        if self._unit_c:
            return self._unit
        else:
            m = self.magnitude()
            try:
                unit = self / m
                self._unit = Point(unit.x, unit.y, unit.z)
                self._unit_c = True
                return self._unit
            except ZeroDivisionError:
                raise ValueError('cannot normalize a zero vector')

    cpdef double euclidean(self, Point p):
        """\
        Return the Euclidean distance from this point to another.

        @param p: The other point.
        @type p: L{Point}
        @return: Euclidean distance.
        @rtype: C{float}
        """
        return sqrt((self.x - p.x) ** 2 + \
                    (self.y - p.y) ** 2 + \
                    (self.z - p.z) ** 2)

    def angle(self, Point p):
        """\
        Return the angle between this vector and another.

        @param p: The other vector.
        @type p: L{Point}
        @return: Angle in radians.
        @rtype: L{Angle}
        """
        return Angle(acos(p.unit().dot(self.unit())))

    def to_list(self):
        """\
        Return a list with the three components of this object.
        
        @return: List form of this object.
        @rtype: C{list}
        """
        return [self.x, self.y, self.z]


cdef class DirectionalPoint(Point):
    """\
    3D directional point (spatial-directional vector) class.
    """
    def __cinit__(self, x, y, z, rho, eta):
        """\
        Constructor.
        """
        self.rho, self.eta = Angle(rho), Angle(eta)
        if self.rho > pi:
            self.rho -= 2. * (self.rho - pi)
            self.eta += pi

    def __reduce__(self):
        return (DirectionalPoint, (self.x, self.y, self.z, self.rho, self.eta))

    def __hash__(self):
        """\
        Hash function. Intentionally collides on points which are very close to
        each other (per the string representation precision).
        """
        return hash(repr(self))

    def __getitem__(self, i):
        return (self.x, self.y, self.z, self.rho, self.eta).__getitem__(i)

    def __richcmp__(self, DirectionalPoint p, int t):
        eq = abs(self.x - p.x) < 1e-4 and \
             abs(self.y - p.y) < 1e-4 and \
             abs(self.z - p.z) < 1e-4 and \
             abs(self.rho - p.rho) < 1e-4 and \
             abs(self.eta - p.eta) < 1e-4
        if t == 2:
            return eq
        if t == 3:
            return not eq

    cpdef DirectionalPoint _add(self, Point p):
        return DirectionalPoint(self.x + p.x, self.y + p.y, self.z + p.z,
            self.rho, self.eta)

    cpdef DirectionalPoint _sub(self, Point p):
        return DirectionalPoint(self.x - p.x, self.y - p.y, self.z - p.z,
            self.rho, self.eta)

    cpdef DirectionalPoint _mul(self, double s):
        return DirectionalPoint(self.x * s, self.y * s, self.z * s,
            self.rho, self.eta)

    cpdef DirectionalPoint _div(self, double s):
        return DirectionalPoint(self.x / s, self.y / s, self.z / s,
            self.rho, self.eta)

    cpdef DirectionalPoint _neg(self):
        return DirectionalPoint(-self.x, -self.y, -self.z,
            self.rho + pi, self.eta)

    def __neg__(self):
        """\
        Negation.

        @return: Result vector.
        @rtype: L{DirectionalPoint}
        """
        return self._neg()

    def __repr__(self):
        """\
        Canonical string representation.

        @return: Spatial-directional vector string.
        @rtype: C{str}
        """
        return '%s(%.4f, %.4f, %.4f, %.4f, %.4f)' % (type(self).__name__,
            self.x, self.y, self.z, self.rho, self.eta)

    def __str__(self):
        """\
        String representation, displays in a tuple format.

        @return: Spatial-directional vector string.
        @rtype: C{str}
        """
        return '(%.4f, %.4f, %.4f, %.4f, %.4f)' % \
            (self.x, self.y, self.z, self.rho, self.eta)

    cpdef Point direction_unit(self):
        """\
        Unit vector representation of the direction of this directional point.

        @rtype: L{Point}
        """
        return Point(sin(self.rho) * cos(self.eta),
                     sin(self.rho) * sin(self.eta), cos(self.rho))


cdef class Quaternion:
    """\
    Quaternion class.
    """
    def __cinit__(self, a, v):
        self.a = a
        self.v = v

    def __reduce__(self):
        return (Quaternion, (self.a, self.v))

    def __hash__(self):
        return hash(self.a) + hash(self.v)

    def __richcmp__(self, q, int t):
        if not isinstance(q, Quaternion):
            return False
        if t == 2:
            return abs(self.a - q.a) < 1e-4 and self.v == q.v
        if t == 3:
            return not (abs(self.a - q.a) < 1e-4 and self.v == q.v)

    cpdef Quaternion _add(self, Quaternion q):
        return Quaternion(self.a + q.a, self.v._add(q.v))

    def __add__(self, Quaternion q):
        """\
        Quaternion addition.

        @param q: The operand quaternion.
        @type q: L{Quaternion}
        @return: Result quaternion.
        @rtype: L{Quaternion}
        """
        return self._add(q)

    cpdef Quaternion _sub(self, Quaternion q):
        return Quaternion(self.a - q.a, self.v._sub(q.v))

    def __sub__(self, Quaternion q):
        """\
        Quaternion subtraction.

        @param q: The operand quaternion.
        @type q: L{Quaternion}
        @return: Result quaternion.
        @rtype: L{Quaternion}
        """
        return self._sub(q)

    cpdef Quaternion _mul(self, Quaternion q):
        return Quaternion(self.a * q.a - self.v.dot(q.v),
            q.v._mul(self.a) + self.v._mul(q.a) + self.v.cross(q.v))

    def __mul__(self, Quaternion q):
        """\
        Quaternion multiplication.

        @param q: The operand scalar or quaternion.
        @type q: L{Quaternion}
        @return: Result quaternion.
        @rtype: L{Quaternion}
        """
        return self._mul(q)

    cpdef Quaternion _div(self, double s):
        return Quaternion(self.a / s, self.v / s)

    def __div__(self, double s):
        """\
        Scalar division.

        @param s: The scalar divisor.
        @type s: C{float}
        @return: Result quaternion.
        @rtype: L{Quaternion}
        """
        return self._div(s)

    cpdef Quaternion _neg(self):
        return Quaternion(-self.a, -self.v)

    def __neg__(self):
        """\
        Negation.

        @return: Result quaternion.
        @rtype: L{Quaternion}
        """
        return self._neg()

    def __repr__(self):
        """\
        Canonical string representation.

        @return: Canonical string representation.
        @rtype: C{str}
        """
        return '%s(%f, %s)' % (type(self).__name__, self.a, self.v)

    def __str__(self):
        """\
        String representation, displays in a tuple format.

        @return: Vector string.
        @rtype: C{str}
        """
        return '(%.4f, %s)' % (self.a, self.v)

    cpdef double dot(self, Quaternion q):
        """\
        Dot product.
        
        @param q: The operand quaternion.
        @type q: L{Quaternion}
        @return: Dot product.
        @rtype: C{float}
        """
        return self.a * q.a + self.v.x * q.v.x + self.v.y * q.v.y + \
               self.v.z * q.v.z

    cpdef double magnitude(self):
        """\
        Magnitude (norm) of this quaternion.

        @rtype: C{float}
        """
        if self._magnitude_c:
            return self._magnitude
        else:
            self._magnitude = sqrt(self.a ** 2 + self.v.x ** 2 + \
                                   self.v.y ** 2 + self.v.z ** 2)
            self._magnitude_c = True
            return self._magnitude

    cpdef Quaternion unit(self):
        """\
        Versor (unit quaternion) of this quaternion.

        @rtype: L{Quaternion}
        """
        if self._unit_c:
            return self._unit
        else:
            try:
                self._unit = self / self.magnitude()
                self._unit_c = True
                return self._unit
            except ZeroDivisionError:
                raise ValueError('cannot normalize a zero quaternion')

    cpdef Quaternion conjugate(self):
        """\
        Conjugate of this quaternion.

        @rtype: L{Quaternion}
        """
        if self._conjugate_c:
            return self._conjugate
        else:
            self._conjugate = Quaternion(self.a, -self.v)
            self._conjugate_c = True
            return self._conjugate

    cpdef Quaternion inverse(self):
        """\
        Multiplicative inverse of this quaternion.

        @rtype: L{Quaternion}
        """
        if self._inverse_c:
            return self._inverse
        else:
            self._inverse = self.conjugate() / (self.magnitude() ** 2)
            self._inverse_c = True
            return self._inverse

    cpdef double distance(self, Quaternion q):
        """\
        Distance between two quaternions.
        
        @param q: The operand quaternion.
        @type q: L{Quaternion}
        @return: Distance.
        @rtype: C{float}
        """
        return (self.unit() - q.unit()).magnitude()


cdef class Rotation:
    """\
    3D Euclidean rotation class. Handles multiple representations of SO(3).
    """
    def __init__(self, Q=Quaternion(1, Point(0, 0, 0))):
        """\
        Constructor.
        """
        self.Q = Q.unit()

    def __reduce__(self):
        return (Rotation, (self.Q,))

    def __hash__(self):
        return hash(self.Q)

    def __repr__(self):
        """\
        Canonical string representation.

        @return: Canonical string representation.
        @rtype: C{str}
        """
        return '%s(%s)' % (type(self).__name__, str(self.Q))

    def __richcmp__(self, Rotation r, int t):
        if t == 2:
            return self.Q == r.Q
        elif t == 3:
            return not self.Q == r.Q

    cpdef Rotation _add(self, Rotation other):
        return Rotation(self.Q._mul(other.Q))

    def __add__(self, Rotation other):
        """\
        Rotation composition.

        @param other: The other rotation.
        @type other: L{Rotation}
        @return: The composed rotation.
        @rtype: L{Rotation}
        """
        return self._add(other)

    def __sub__(self, Rotation other):
        """\
        Rotation composition with the inverse.

        @param other: The other rotation.
        @type other: L{Rotation}
        @return: The composed rotation.
        @rtype: L{Rotation}
        """
        return self._add(-other)

    def __neg__(self):
        """\
        Negation.

        @return: The inverse rotation.
        @rtype: L{Rotation}
        """
        return self.inverse()

    cpdef Rotation inverse(self):
        return Rotation(self.Q.inverse())

    cpdef Point rotate(self, Point p):
        """\
        Rotate a vector.

        @param p: The vector to rotate.
        @type p: L{Point}
        @return: The rotated vector.
        @rtype: L{Point}
        """
        return (self.Q._mul(Quaternion(0, p))._mul(self.Q.inverse())).v

    @classmethod
    def from_rotation_matrix(cls, R):
        """\
        Generate the internal quaternion representation from a rotation matrix.

            - U{http://en.wikipedia.org/wiki/Rotation_matrix#Quaternion}

        @param R: The rotation matrix.
        @type R: C{list} of C{list}
        @return: Quaternion representation of the rotation.
        @rtype: L{Rotation}
        """
        cdef double a, b, c, d
        if (1.0 + R[0][0] + R[1][1] + R[2][2]) < 0 and \
            (1.0 + R[0][0] + R[1][1] + R[2][2]) > -1e-4:
            a = 0
        else:
            a = 0.5 * sqrt(1.0 + R[0][0] + R[1][1] + R[2][2])
        if (1 + R[0][0] - R[1][1] - R[2][2]) < 0 and \
            (1 + R[0][0] - R[1][1] - R[2][2]) > -1e-4:
            b = copysign(0, R[2][1] - R[1][2])
        else:
            b = copysign(0.5 * sqrt(1 + R[0][0] - R[1][1] - R[2][2]), R[2][1] - \
                R[1][2])
        if (1 - R[0][0] + R[1][1] - R[2][2]) < 0 and \
            (1 - R[0][0] + R[1][1] - R[2][2]) > -1e-4:
            c = copysign(0, R[0][2] - R[2][0])
        else:
            c = copysign(0.5 * sqrt(1 - R[0][0] + R[1][1] - R[2][2]), R[0][2] - \
                R[2][0])
        if (1 - R[0][0] - R[1][1] + R[2][2]) < 0 and \
            (1 - R[0][0] - R[1][1] + R[2][2]) > -1e-4:
            d = copysign(0, R[1][0] - R[0][1])
        else:
            d = copysign(0.5 * sqrt(1 - R[0][0] - R[1][1] + R[2][2]), R[1][0] - \
                R[0][1])
        return Rotation(Quaternion(a, Point(b, c, d)))

    @classmethod
    def from_axis_angle(cls, double theta, axis):
        """\
        Generate the internal quaternion representation from an axis and
        angle representation.

        @param theta: The angle of rotation.
        @type theta: L{Angle}
        @param axis: The axis of rotation.
        @type axis: L{Point}
        @return: Quaternion representation of the rotation.
        @rtype: L{Rotation}
        """
        if abs(theta) < 1e-4 and axis == Point(0,0,0):
            return Rotation(Quaternion(1, Point(0,0,0)))
        else:
            return Rotation(Quaternion(cos(theta / 2.0), \
                axis.unit() * sin(theta / 2.0)))

    @classmethod
    def from_euler(cls, convention, angles):
        """\
        Generate the internal quaternion representation from Euler angles.

        @param convention: The convention to use (e.g. C{zyx}).
        @type convention: C{str}
        @param angles: The angles of rotation.
        @type angles: C{tuple} of L{Angle}
        @return Quaternion representation of the rotation.
        @rtype: L{Rotation}
        """
        cdef double a, b, c, d
        def qterm(index):
            binarize = lambda x: [(x >> 2) % 2, (x >> 1) % 2, x % 2]
            return copysign(1, index) * reduce(lambda a, b: a * b,
                [(sin if bit else cos)(angles[i] / 2.0) \
                for i, bit in enumerate(binarize(abs(index)))])
        eulerquat = {'xyx': [0, -5, 1, 4, 2, 7, 3, -6],
                     'xyz': [0, -7, 1, 6, 2, -5, 3, 4],
                     'xzx': [0, -5, 1, 4, -3, 6, 2, 7],
                     'xzy': [0, 7, 1, -6, -3, 4, 2, 5],
                     'yxy': [0, -5, 2, 7, 1, 4, -3, 6],
                     'yxz': [0, 7, 2, 5, 1, -6, -3, 4],
                     'yzx': [0, -7, 3, 4, 1, 6, 2, -5],
                     'yzy': [0, -5, 3, -6, 1, 4, 2, 7],
                     'zxy': [0, -7, 2, -5, 3, 4, 1, 6],
                     'zxz': [0, -5, 2, 7, 3, -6, 1, 4],
                     'zyx': [0, 7, -3, 4, 2, 5, 1, -6],
                     'zyz': [0, -5, -3, 6, 2, 7, 1, 4]}
        a, b, c, d = [sum([qterm(eulerquat[convention][i + j * 2]) \
                      for i in range(2)]) for j in range(4)]
        if a > 0:
            return Rotation(Quaternion(a, Point(-b, -c, -d)))
        else:
            return Rotation(Quaternion(-a, Point(b, c, d)))

    def to_rotation_matrix(self):
        """\
        Return the rotation matrix representation from the internal quaternion
        representation.

            - U{http://en.wikipedia.org/wiki/Rotation_matrix#Quaternion}

        @return: Rotation matrix.
        @rtype: C{list} of C{list}
        """
        cdef double a, b, c, d, Nq, s
        cdef double B, C, D, aB, aC, aD, bB, bC, bD, cC, cD, dD
        a = self.Q.a
        b, c, d = self.Q.v.x, self.Q.v.y, self.Q.v.z
        Nq = a ** 2 + b ** 2 + c ** 2 + d ** 2
        if Nq > 0:
            s = 2.0 / Nq
        else:
            s = 0.0
        B = b * s; C = c * s; D = d * s
        aB = a * B; aC = a * C; aD = a * D
        bB = b * B; bC = b * C; bD = b * D
        cC = c * C; cD = c * D; dD = d * D
        return [[1.0 - (cC + dD), bC - aD, bD + aC],
                [bC + aD, 1.0 - (bB + dD), cD - aB],
                [bD - aC, cD + aB, 1.0 - (bB + cC)]]

    def to_axis_angle(self):
        """\
        Return the axis and angle representation from the internal quaternion
        representation.

        @return: Axis and angle rotation form.
        @rtype: C{tuple} of L{Angle} and L{Point}
        """
        theta = Angle(copysign(2.0 * acos(self.Q.a), self.Q.v.magnitude()))
        try:
            return (theta, self.Q.v.unit())
        except ValueError:
            return (theta, Point(1.0, 0.0, 0.0))

    def to_euler_zyx(self):
        """\
        Return three fixed-axis (Euler zyx) rotation angles from the internal
        rotation matrix representation.

        @return: Three fixed-axis (Euler zyx) angle rotation form.
        @rtype: C{tuple} of L{Angle}
        """
        cdef double a, b, c, d
        a = self.Q.a
        b, c, d = self.Q.v.x, self.Q.v.y, self.Q.v.z
        theta = Angle(atan2(2.0 * (c * d - a * b),
                            1.0 - 2.0 * (b ** 2 + c ** 2)))
        phi = Angle(-asin(2.0 * (a * c + d * b)))
        psi = Angle(atan2(2.0 * (b * c - a * d), 1.0 - 2.0 * (c ** 2 + d ** 2)))
        return (theta, phi, psi)


cdef class Pose:
    """\
    Pose (rigid 3D Euclidean transformation) class.
    """
    def __cinit__(self, T=Point(0, 0, 0), R=Rotation()):
        """\
        Constructor.

        @param T: The 3-element translation vector.
        @type T: L{Point}
        @param R: The 3x3 rotation matrix.
        @type R: L{Rotation}
        """
        self.T = T
        self.R = R

    def __reduce__(self):
        return (Pose, (self.T, self.R))

    def __hash__(self):
        return hash(self.T) + hash(self.R)

    def __richcmp__(self, Pose p, int t):
        if t == 2:
            return self.T == p.T and self.R == p.R
        elif t == 3:
            return not (self.T == p.T and self.R == p.R)

    cpdef Pose _add(self, Pose other):
        cdef Point Tnew
        cdef Rotation Rnew
        Tnew = other.R.rotate(self.T)._add(other.T)
        Rnew = other.R._add(self.R)
        return Pose(Tnew, Rnew)

    def __add__(self, Pose other):
        """\
        Pose composition: M{PB(PA(x)) = (PA + PB)(x)}.

        @param other: The other pose transformation.
        @type other: L{Pose}
        @return: Composed transformation.
        @rtype: L{Pose}
        """
        return self._add(other)

    def __sub__(self, Pose other):
        """\
        Pose composition with the inverse.

        @param other: The other pose transformation.
        @type other: L{Pose}
        @return: Composed transformation.
        @rtype: L{Pose}
        """
        return self._add(other.inverse())

    def __neg__(self):
        """\
        Pose inversion (with caching).

        @return: Inverted pose.
        @rtype: L{Pose}
        """
        return self.inverse()

    def __repr__(self):
        """\
        String representation, display T and R.

        @return: String representations of T and R.
        @rtype: C{str}
        """
        return '%s(%s, %s)' % (type(self).__name__, self.T, self.R)

    cpdef Pose inverse(self):
        if self._inverse_c:
            return self._inverse
        else:
            self._inverse = Pose((self.R.inverse()).rotate(self.T)._neg(),
                self.R.inverse())
            self._inverse_c = True
            return self._inverse

    cpdef Point _map(self, Point p):
        return self.R.rotate(p)._add(self.T)

    cpdef Point _dmap(self, Point p):
        cdef Point unit
        cdef double rho, eta
        q = self.R.rotate(p)
        unit = self.R.rotate(p.direction_unit())
        try:
            rho = acos(unit.z)
        except ValueError:
            if unit.z > 0:
                rho = 0.0
            else:
                rho = pi
        eta = atan2(unit.y, unit.x)
        return DirectionalPoint(q.x, q.y, q.z, rho, eta)._add(self.T)

    cpdef Point map(self, Point p):
        """\
        Map a point/vector through this pose.

        @param p: The point/vector to transform.
        @type p: L{Point}
        @return: The mapped point/vector.
        @rtype: L{Point}
        """
        if type(p) is DirectionalPoint:
            return self._dmap(p)
        else:
            return self._map(p)


cdef class Face:
    """\
    Face class.
    """
    def __cinit__(self, *args):
        """\
        Constructor.

        @param v: Vertices (in counterclockwise order looking at the face).
        @type v: C{tuple} of L{Point}
        """
        self.vertices = args

    def __reduce__(self):
        return (Face, (self.vertices,))

    def __hash__(self):
        return hash(self.vertices)

    def __repr__(self):
        """\
        Canonical string representation.

        @return: Canonical string representation.
        @rtype: C{str}
        """
        return '%s(%s)' % (type(self).__name__, self.vertices)

    cpdef object edges(self):
        """\
        Edges of this face.

        @rtype: C{list} of L{Point}
        """
        if self._edges_c:
            return self._edges
        else:
            self._edges = [self.vertices[(i + 1) % len(self.vertices)] \
                - self.vertices[i] for i in range(len(self.vertices))]
            self._edges_c = True
            return self._edges

    cpdef Point normal(self):
        """\
        Normal vector to this face.

        @rtype: L{Point}
        """
        if self._normal_c:
            return self._normal
        else:
            self._normal = (self.edges()[0].cross(self.edges()[1])).unit()
            self._normal_c = True
            return self._normal

    cpdef Pose planing_pose(self):
        """\
        Pose which transforms this face into the x-y plane, with the first
        vertex at the origin.

        @rtype: L{Pose}
        """
        if self._planing_pose_c:
            return self._planing_pose
        else:
            angle = self.normal().angle(Point(0, 0, 1))
            axis = self.normal().cross(Point(0, 0, 1))
            try:
                R = Rotation.from_axis_angle(angle, axis)
            except ValueError:
                R = Rotation()
            self._planing_pose = Pose(T=R.rotate(self.vertices[0])._neg(), R=R)
            self._planing_pose_c = True
            return self._planing_pose

    cpdef double dist_to_point(self, Point p):
        """\
        Compute the distance from a point to this face.

        @param p: The 3D point.
        @type p: L{Point}
        @return: The distance.
        @rtype: C{double}
        """
        cdef double sn, sd, sb
        cdef Point b
        sn = -(self.normal().dot(p - self.vertices[2]))
        sd = self.normal().dot(self.normal())
        sb = sn / sd
        b = p + self.normal()._mul(sb)
        return p.euclidean(b)

    cpdef object normal_angles(self):
        """\
        Compute the polar (rho) and azimuth (eta) angles of the
        normal of this face.

        @return: The polar and azimuth angles.
        @rtype: C{tuple} of C{float}
        """
        cdef Point normal
        normal = self.normal()
        rho = normal.angle(Point(0, 0, 1))
        eta = Angle(atan2(normal.y, normal.x))
        return (rho, eta)


cdef class Triangle(Face):
    """\
    Triangle class.
    """
    def __init__(self, *args):
        """\
        Constructor.

        @param v: Vertices (in counterclockwise order looking at the face).
        @type v: C{tuple} of L{Point}
        """
        if len(self.vertices) > 3:
            self.vertices = self.vertices[:3]
        self._vertex_0 = self.vertices[0]
        self._vertex_1 = self.vertices[1]
        self._vertex_2 = self.vertices[2]
        self._edge_0 = self.edges()[0]
        self._edge_1 = self.edges()[1]
        self._edge_2 = self.edges()[2]

    def __hash__(self):
        return hash(self.vertices)

    def __richcmp__(self, Triangle tri, int t):
        eq = (self.vertices[0] - tri.vertices[0]).magnitude() < 1e-4 and \
             (self.vertices[1] - tri.vertices[1]).magnitude() < 1e-4 and \
             (self.vertices[2] - tri.vertices[2]).magnitude() < 1e-4
        if t == 2:
            return eq
        if t == 3:
            return not eq

    cpdef Triangle pose_map(self, Pose pose):
        """\
        Map triangle through a pose.

        @param pose: The pose through which to map the triangle.
        @type pose: L{Pose}
        @return: The mapped triangle.
        @rtype: L{Triangle}
        """
        return Triangle(pose._map(self._vertex_0),
                        pose._map(self._vertex_1),
                        pose._map(self._vertex_2))

    cpdef Point intersection(self, Point origin, Point end, bool limit):
        """\
        Return the point of intersection of the line or line segment between the
        two given points with this triangle.

            - T. Moller and B. Trumbore, "Fast, Minimum Storage Ray/Triangle
              Intersection," J. Graphics Tools, vol. 2, no. 1, pp. 21-28, 1997.

        @param origin: The origin of the segment.
        @type origin: L{Point}
        @param end: The end of the segment.
        @type end: L{Point}
        @param limit: If true, limit intersection to the line segment.
        @type limit: C{bool}
        @return: The point of intersection.
        @rtype: L{Point}
        """
        cdef Point origin_end, direction, P, T, Q
        cdef double det, inv_det, u, v, t
        origin_end = end._sub(origin)
        direction = origin_end.unit()
        P = direction.cross(self._edge_2._neg())
        det = self._edge_0.dot(P)
        if det > -1e-4 and det < 1e-4:
            return None
        inv_det = 1.0 / det
        T = origin._sub(self._vertex_0)
        u = (T.dot(P)) * inv_det
        if u < 0 or u > 1.0:
            return None
        Q = T.cross(self._edge_0)
        v = (direction.dot(Q)) * inv_det
        if v < 0 or u + v > 1.0:
            return None
        t = (Q.dot(self._edge_2._neg())) * inv_det
        if limit and (t < 1e-04 or t > origin_end.magnitude() - 1e-04):
            return None
        return origin._add(direction._mul(t))

    cpdef bool overlap(self, Triangle other):
        """\
        Return whether this triangle intersects another.

            - T. Moller, "A Fast Triangle/Triangle Intersection Test," J.
              Graphics Tools, vol. 2, no. 2, pp. 25-30, 1997.

        @param other: The other triangle.
        @type other: L{Triangle}
        @return: True if the triangles intersect one another.
        @rtype: C{bool}
        """
        cdef Triangle triangle
        cdef int i, axis, odd
        cdef float dv
        dvs = {}
        dvs[other] = [other.vertices[i].dot(self.normal()) + \
            (self.vertices[0].dot(self.normal()._neg())) for i in range(3)]
        if all([dv > 1e-4 for dv in dvs[other]]) \
        or all([dv < -1e-4 for dv in dvs[other]]):
            return False
        dvs[self] = [self.vertices[i].dot(other.normal()) + \
            (other.vertices[0].dot(other.normal()._neg())) for i in range(3)]
        if all([dv > 1e-4 for dv in dvs[self]]) \
        or all([dv < -1e-4 for dv in dvs[self]]):
            return False
        if all([abs(dv) < 1e-4 for dv in dvs[self]]):
            # project both triangles onto axis-aligned plane.
            pose1 = self.planing_pose()
            pose2 = other.planing_pose()
            pose12 = pose2 - pose1
            new_self = self.pose_map(pose1)
            new_other = self.pose_map(pose1 + pose12)
            # check edges of self for intersection with edges of other.
            index = [0,1,2,0]
            v = new_self.vertices
            self_edges = [[v[index[i]], v[index[i+1]]] for i in range(3)]
            v = new_other.vertices
            other_edges = [[v[index[i]], v[index[i+1]]] for i in range(3)]
            for self_edge in self_edges:
                for other_edge in other_edges:
                    if segment_intersect(self_edge[0], self_edge[1], \
                        other_edge[0], other_edge[1]):
                        return True
            # check vertex of self for point-in-triangle with other
            # and vice versa (Haines 1994).
            for vertex in other.vertices:
                if self.has_point(vertex):
                    return True
            for vertex in self.vertices:
                if other.has_point(vertex):
                    return True
            return False
        else:
            normal = tuple(self.normal().cross(other.normal()))
            axis = normal.index(max(normal))
            t = {self: [], other: []}
            for triangle in (self, other):
                signs = [dv > 0 for dv in dvs[triangle]]
                odd = signs.index(bool(sum(signs) % 2))
                for i in range(3):
                    if i == odd:
                        continue
                    t[triangle].append(triangle.vertices[i][axis] + \
                        (triangle.vertices[odd][axis] - \
                        triangle.vertices[i][axis]) * (dvs[triangle][i] / \
                        (dvs[triangle][i] - dvs[triangle][odd])))
                t[triangle].sort()
        if t[self][1] < t[other][0] or t[other][1] < t[self][0]:
            return False
        return True

    cpdef bool has_point(self, Point p):
        """\
        Check if a point is inside the triangle.

            - E. Haines, "Point in Polygon Strategies," in Graphics Gems IV,
              P. S. Heckbert, ed., Academic Press Professional, pp. 24-46, 1994.

        @param p: The point to check.
        @type p: L{Point}
        @return: Whether the point is inside or not.
        @rtype: C{bool}
        """
        # Check if the point is on the same plane as the triangle. If not, then
        # return false.
        if self.dist_to_point(p) > 1e-4:
            return False
        # The point in polygon check does not always work when the point is in the
        # boundaries, the following tries to catch this.
        cdef int j = 2
        for i in [0,1,2]:
            if point_in_segment(self.vertices[i], self.vertices[j], p):
                return True
            j = i
        # If the point is on the same plane, then transform both using the
        # pose of the plane.
        cdef Pose pose = self.planing_pose()
        cdef Triangle triangle_m = self.pose_map(pose)
        cdef Point p_m = pose._map(p)
        # Check for point in polygon (Haines 1994).
        j = 2
        cdef bool c = False
        for i in [0,1,2]:
            if (((triangle_m.vertices[i].y > p_m.y) != \
                (triangle_m.vertices[j].y > p_m.y)) and \
                (p_m.x < (triangle_m.vertices[j].x - triangle_m.vertices[i].x) * \
                (p_m.y - triangle_m.vertices[i].y) / \
                (triangle_m.vertices[j].y - triangle_m.vertices[i].y) + \
                triangle_m.vertices[i].x)):
                c = not c
            j = i
        return c


cpdef bool point_in_segment(Point s1, Point s2, Point p):
    """\
    Check if a point is in the line segment.

    @param s1: The first point of the segment.
    @type s1: L{Point}
    @param s2: The second point of the segment.
    @type s2: L{Point}
    @param p: The point to check.
    @type p: L{Point}
    @return: Whether the point is in the segment or not.
    @rtype: C{bool}
    """
    cdef Point s, s1p
    s = s2 - s1
    s1p = p - s1
    if s.cross(s1p).magnitude() > 1e-4:
        return False
    if s.dot(s1p) >= 0 and s.dot(s1p) <= s.dot(s):
        return True
    else:
        return False

cpdef double point_segment_dis(Point s1, Point s2, Point p):
    """\
    Return the distance from  point to a line segment along the line that is
    perpendicular to the line segment and that pases through the point.
    
        - U{http://mathworld.wolfram.com/Point-LineDistance3-Dimensional.html}
    
    @param s1: The first point of the segment.
    @type s1: L{Point}
    @param s2: The second point of the segment.
    @type s2: L{Point}
    @param p: The point to check.
    @type p: L{Point}
    @return: The distance.
    @rtype: C{double}
    """
    return ((p - s1).cross(p - s2)).magnitude() / (s2 - s1).magnitude()

cpdef bool segment_intersect(Point p1, Point p2, Point q1, Point q2):
    """\
    Check if two line segments (on the x-y plane) intersect each other.

    @param p1: The start point of the first segment.
    @type p1: L{Point}
    @param p2: The end point of the first segment.
    @type p2: L{Point}
    @param q1: The start point of the second segment.
    @type q1: L{Point}
    @param q2: The end point of the second segment.
    @type q2: L{Point}
    @return: True if the line segments intersect each other.
    @rtype C{bool}
    """
    cdef Point p, q
    cdef double p_s, q_s
    p = p2 - p1
    q = q2 - q1
    if p.cross(q).magnitude() < 1e-4:
        return False
    p_s = (q1 - p1).cross_2d(q) / p.cross_2d(q)
    q_s = (p1 - q1).cross_2d(p) / q.cross_2d(p)
    if p_s >= 0 and p_s <= 1 and q_s >= 0 and q_s <= 1:
        return True
    return False

cdef int which_side(object points, Point direction, Point vertex):
    """\
    Check which side of the projection of the given vertex onto the given
    direction the projections of the given points lie upon.

        - D. Eberly, "Intersection of Convex Objects: The Method of Separating
          Axes," 2008.

    @param points: The points to check.
    @type points: C{list} of L{Point}
    @param direction: The direction upon which to project.
    @type direction: L{Point}
    @param vertex: The criterion vertex.
    @type vertex: L{Point}
    @return: 1 if positive side, -1 if negative side, 0 if both.
    @rtype: C{int}
    """
    cdef Point point
    cdef int positive, negative
    cdef double t
    positive, negative = 0, 0
    for point in points:
        t = direction.dot(point._sub(vertex))
        if t > 0:
            positive += 1
        elif t < 0:
            negative += 1
        if positive and negative:
            return 0
    if positive:
        return 1
    else:
        return -1


cpdef bool triangle_frustum_intersection(Triangle triangle, object hull):
    """\
    Check whether a triangle intersects a frustum.

        - D. Eberly, "Intersection of Convex Objects: The Method of Separating
          Axes," 2008.

    @param triangle: The triangle to check.
    @type triangle: L{Triangle}
    @param hull: The vertices of the frustum to check.
    @type hull: C{list} of L{Point}
    @return: True if the triangle intersects the frustum.
    @rtype: C{bool}
    """
    cdef Point fedge, fvertex
    cdef int i, side0, side1
    edges = [(hull[i] - hull[0], hull[0]) for i in range(1, 5)] + \
            [(hull[(i + 1) % 4 + 1] - hull[i + 1], hull[i + 1]) \
            for i in range(4)]
    faces = [Face(hull[4], hull[3], hull[2], hull[1])] + \
            [Face(hull[0], hull[i + 1], hull[(i + 1) % 4 + 1]) \
            for i in range(4)]
    for face in faces:
        if which_side(triangle.vertices, face.normal(), face.vertices[0]) > 0:
            return False
    if which_side(hull, triangle.normal(), triangle._vertex_0) > 0:
        return False
    for fedge, fvertex in edges:
        for i in range(3):
            direction = fedge.cross(triangle.edges()[i])
            side0 = which_side(hull, direction, fvertex)
            if side0 == 0:
                continue
            side1 = which_side(triangle.vertices, direction, fvertex)
            if side1 == 0:
                continue
            if side0 * side1 < 0:
                return False
    return True


cpdef Point avg_points(object points):
    """\
    Average a set of points.

    @param points: The points.
    @type points: C{list} of L{Point}
    @return: The average.
    @rtype: L{Point}
    """
    cdef int n = len(points)
    cdef Point avg = Point(0,0,0)
    for i in range(n):
        avg += points[i]
    return avg._div(float(n))


cpdef Quaternion avg_quaternions(object qts):
    """\
    Average a set of quaternions.

    @param qts: The quaternions.
    @type qts: C{list} of L{Quaternion}
    @return: The average.
    @rtype: L{Quaternion}
    """
    cdef int n = len(qts)
    cdef double mag
    cdef Quaternion avg = Quaternion(0, Point(0,0,0))
    for i in range(n):
        if qts[0] * qts[i] > 0.0:
            avg += qts[i]
        else:
            qts[i] = qts[i].conjugate()
            avg -= qts[i]
    mag = avg.magnitude()
    if mag > 0.0:
        return avg._div(mag)
    else:
        raise ValueError('Cannot normalize a zero vector.')


def avg_poses(poses):
    """\
    Compute the pose average of a set of poses.

    @param poses: The list of poses.
    @type poses: C{list} of L{Pose}
    @return: The averaged pose.
    @rtype: L{Pose}
    """
    T = []
    Q = []
    for pose in poses:
        T.append(pose.T)
        Q.append(pose.R.Q)
    return Pose(avg_points(T), Rotation(avg_quaternions(Q)))


def random_unit_vector():
    """\
    Return a random unit vector, uniformly distributed over the locus of the
    unit sphere.

    @return: Random unit vector.
    @rtype: L{Point}
    """
    while True:
        rv = Point(uniform(-1, 1), uniform(-1, 1), uniform(-1, 1))
        if rv.magnitude() < 1:
            return rv.unit()


def pose_error(pose, taxis, double terror, raxis, double rerror):
    """\
    Introduce translation error of a specified magnitude and direction and
    rotation error of a specified angle about a specified axis, and return the
    resulting pose.

    @param pose: The original pose.
    @type pose: L{Pose}
    @param taxis: The axis (direction) of the translation error.
    @type taxis: L{Point}
    @param terror: The translation error in units of distance.
    @type terror: C{float}
    @param raxis: The axis of the rotation error.
    @type raxis: L{Point}
    @param rerror: The rotation error in radians.
    @type rerror: L{Angle}
    @return: The pose with introduced error.
    @rtype: L{Pose}
    """
    T, R = pose.T, pose.R
    T += terror * taxis.unit()
    R = Rotation.from_axis_angle(rerror, raxis.unit()) + R
    return Pose(T=T, R=R)


def gaussian_pose_error(pose, double tsigma, double rsigma):
    """\
    Introduce random Gaussian noise to the specified pose and return the noisy
    pose.

    @param p: The original pose.
    @type p: L{Pose}
    @param tsigma: The standard deviation of the translation error.
    @type tsigma: C{float}
    @param rsigma: The standard deviation of the rotation error.
    @type rsigma: C{float}
    @return: The pose with introduced error.
    @rtype: L{Pose}
    """
    T, R = pose.T, pose.R
    T = Point(gauss(T.x, tsigma), gauss(T.y, tsigma), gauss(T.z, tsigma))
    R += Rotation.from_euler('zyx', [Angle(gauss(0, rsigma)) for i in range(3)])
    return Pose(T=T, R=R)
