#!/usr/bin/env python

"""\
Unit tests for the various Adolphus modules.

@author: Aaron Mavrinac
@organization: University of Windsor
@contact: mavrin1@uwindsor.ca
@license: GPL-3
"""

import unittest
from math import pi

import adolphus
from adolphus.geometry import Angle, Point, DirectionalPoint, Pose, Rotation, Triangle
from adolphus.yamlparser import YAMLParser
print('Adolphus imported from "%s"' % adolphus.__path__[0])


class TestGeometry(unittest.TestCase):
    """\
    Tests for the geometry module.
    """
    def setUp(self):
        self.p = Point((3, 4, 5))
        self.dp = DirectionalPoint((-7, 1, 9, 1.3, 0.2))
        self.R = Rotation.from_euler('zyx', (pi, 0, 0))
        self.P1 = Pose(T=Point(), R=self.R)
        self.P2 = Pose(T=Point((3, 2, 1)), R=self.R)

    def test_angle(self):
        a = Angle(0.3)
        self.assertTrue(abs(a - Angle(0.3 + 2 * pi)) < 1e-04)
        b = a + Angle(6.0)
        self.assertTrue(b < a)

    def test_point_addition(self):
        r = Point((-4, 5, 14))
        self.assertEqual(self.p + self.dp, r)
        s = DirectionalPoint((-4, 5, 14, 1.3, 0.2))
        self.assertEqual(self.dp + self.p, s)

    def test_point_rotation(self):
        r = Point((3, -4, -5))
        self.assertEqual(r, self.R.rotate(self.p))
        r = DirectionalPoint((-7, -1, -9, pi - 1.3, 2 * pi - 0.2))
        self.assertEqual(r, self.P1.map(self.dp))

    def test_pose_map(self):
        m = Point((6, -2, -4))
        self.assertEqual(m, self.P2.map(self.p))
        m = DirectionalPoint((-4, 1, -8, pi - 1.3, 2 * pi - 0.2))
        self.assertEqual(m, self.P2.map(self.dp))

    def test_triangle_intersection(self):
        triangle = Triangle((Point((-3, -3, 0)), Point((-3, 2, 0)), Point((4, 1, 0))))
        self.assertTrue(triangle.intersection(Point((-1, -1, 3)), Point((-1, -1, -3))))
        self.assertTrue(triangle.intersection(Point((-1, -1, -3)), Point((-1, -1, 3))))
        self.assertFalse(triangle.intersection(Point((5, 5, 3)), Point((5, 5, -3))))
        self.assertFalse(triangle.intersection(Point((5, 5, 3)), Point((5, 5, 1))))

    def test_triangle_overlap(self):
        triangles = [Triangle((Point(), Point((10, 2, 0)), Point((8, 0, 6)))),
                     Triangle((Point((0, 2, 1)), Point((4, -7, 2)), Point((7, 3, 3)))),
                     Triangle((Point((-1, -1, -1)), Point((-1, -2, 2)), Point((-5, -1, -1))))]
        self.assertTrue(triangles[0].overlap(triangles[1]))
        self.assertTrue(triangles[1].overlap(triangles[0]))
        self.assertFalse(triangles[0].overlap(triangles[2]))
        self.assertFalse(triangles[2].overlap(triangles[0]))
        self.assertFalse(triangles[1].overlap(triangles[2]))
        self.assertFalse(triangles[2].overlap(triangles[1]))


class TestModel01(unittest.TestCase):
    """\
    Test model 01.
    """
    def setUp(self):
        self.model, self.tasks = YAMLParser('test/test01.yaml').experiment

    def test_strength(self):
        p1 = Point((0, 0, 1000))
        p2 = Point((0, 0, 1200))
        self.assertEqual(self.model.strength(p1, self.tasks['R1'].params), self.model['C'].strength(p1, self.tasks['R1'].params))
        self.assertTrue(self.model.strength(p1, self.tasks['R1'].params))
        self.assertFalse(self.model.strength(p2, self.tasks['R1'].params))
        self.model['C'].set_absolute_pose(Pose(T=Point((1000, 0, 0))))
        self.assertFalse(self.model.strength(p1, self.tasks['R1'].params))
        self.model['C'].set_absolute_pose(Pose(R=Rotation.from_axis_angle(pi, Point((1, 0, 0)))))
        self.assertFalse(self.model.strength(p1, self.tasks['R1'].params))

    def test_performance(self):
        self.assertTrue(self.model.performance(self.tasks['R1']) > 0)
        self.assertEqual(self.model.performance(self.tasks['R2']), 0.0)

    def test_occlusion_cache(self):
        depth = self.model._update_occlusion_cache(self.tasks['R1'].params)
        self.assertTrue(self.model._occlusion_cache[depth]['C']['P1'])
        self.assertFalse(self.model._occlusion_cache[depth]['C']['P2'])
        self.model['C'].set_absolute_pose(Pose(R=Rotation.from_axis_angle(-pi / 2.0, Point((1, 0, 0)))))
        depth = self.model._update_occlusion_cache(self.tasks['R1'].params)
        self.assertFalse(self.model._occlusion_cache[depth]['C']['P1'])
        self.assertTrue(self.model._occlusion_cache[depth]['C']['P2'])
        self.model['C'].set_absolute_pose(Pose(R=Rotation.from_axis_angle(pi, Point((1, 0, 0)))))
        depth = self.model._update_occlusion_cache(self.tasks['R1'].params)
        self.assertFalse(self.model._occlusion_cache[depth]['C']['P1'])
        self.assertFalse(self.model._occlusion_cache[depth]['C']['P2'])


if __name__ == '__main__':
    unittest.main()
