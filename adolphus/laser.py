"""\
Laser range imaging module. Contains extensions and objects necessary for
modeling laser line based range imaging cameras.

@author: Aaron Mavrinac
@organization: University of Windsor
@contact: mavrin1@uwindsor.ca
@license: GPL-3
"""

from math import pi, sin, cos, tan

from .geometry import Angle, Pose, Point, DirectionalPoint
from .coverage import PointCache, RelevanceModel, Camera, Model
from .posable import SceneObject


class LineLaser(SceneObject):
    """\
    Line laser class.
    """
    def __init__(self, name, fan, depth, pose=Pose(), mount=None,
                 primitives=[]):
        """\
        Constructor.

        @param name: The name of the laser.
        @type name: C{str}
        @param fan: Fan angle of the laser line.
        @type fan: L{Angle}
        @param depth: Projection depth of the laser line.
        @type depth: C{float}
        @param pose: Pose of the laser in space (optional).
        @type pose: L{Pose}
        @param mount: Mount object for the laser (optional).
        @type mount: C{object}
        @param primitives: Sprite primitives for the laser.
        @type primitives: C{dict}
        """
        super(LineLaser, self).__init__(name, pose=pose, mount=mount,
            primitives=primitives)
        self._fan = Angle(fan)
        self._depth = depth
        self._generate_laservis()
        self.click_actions = {'ctrl':   'laser %s' % name,
                              'shift':  'modify %s' % name}

    @property
    def fan(self):
        """\
        Fan angle.
        """
        return self._fan

    @property
    def depth(self):
        """\
        Projection depth.
        """
        return self._depth

    def _generate_laservis(self):
        width = self.depth * tan(self.fan / 2.0)
        self.laservis = [{'type': 'curve', 'color': (1, 0, 0),
            'pos': [(0, 0, 0), (-width, 0, self.depth),
                    (width, 0, self.depth), (0, 0, 0)]}]

    def project(self, target, pitch):
        """\
        Generate a range imaging relevance model by projecting the laser line
        onto the target object.

        @param target: The target object.
        @type target: L{SceneObject}
        @param pitch: The horizontal pitch of relevance model points.
        @type pitch: C{float}
        @return: The generated range imaging relevance model.
        @rtype: L{RelevanceModel}
        """
        # FIXME: this ignores occlusions originating outside target
        points = PointCache()
        width = self.depth * tan(self.fan / 2.0)
        x = int(-width / pitch) * pitch
        while x < width:
            cp = None
            origin = self.pose.map(Point((x, 0, 0)))
            end = self.pose.map(Point((x, 0, self.depth)))
            for triangle in target.triangles:
                ip = triangle.intersection(origin, end)
                if ip:
                    ip = (-self.pose).map(ip)
                else:
                    continue
                if abs(ip.x) > ip.z * tan(self.fan / 2.0):
                    continue
                elif not cp or ip.z < cp.z:
                    cp = Point(ip)
            if cp:
                points[DirectionalPoint(tuple(cp) + (pi, 0))] = 1.0
            x += pitch
        return RelevanceModel(points, mount=self)


class RangeCamera(Camera):
    """\
    Single-camera coverage strength model for laser line based range camera.

    A L{RangeCamera} differed from a L{Camera} in that its directional coverage
    assumes perpendicular projection to quantify height resolution.
    """
    def _generate_cd(self):
        aa = cos(self.getparam('angle_max_acceptable'))
        if self.getparam('angle_max_ideal') == \
           self.getparam('angle_max_acceptable'):
            cdval = lambda sigma: float(sigma > aa)
        else:
            ai = cos(self.getparam('angle_max_ideal'))
            cdval = lambda sigma: min(max((sigma - aa) / (ai - aa), 0.0), 1.0)
        def Cd(p):
            try:
                sigma = sin(p.direction_unit.angle(-p))
            except (ValueError, AttributeError):
                # p is at origin or not a directional point
                return 1.0
            else:
                return cdval(sigma)
        self.Cd = Cd


class RangeModel(Model):
    """\
    Multi-camera coverage strength model for laser line based range imaging.

    In addition to the base L{Model} functionality, a L{RangeModel} manages
    line lasers and laser occlusion, and provides range imaging coverage
    methods.
    """
    camera_class = RangeCamera

    def __init__(self, task_params=dict()):
        self.lasers = set()
        super(RangeModel, self).__init__(task_params=task_params)

    def __setitem__(self, key, value):
        if isinstance(value, LineLaser):
            self.lasers.add(key)
        super(RangeModel, self).__setitem__(key, value)

    def __delitem__(self, key):
        self.lasers.discard(key)
        super(RangeModel, self).__delitem__(key)

    # TODO: manage laser occlusions

    def range_coverage(self, laser, target, lpitch, tpitch, taxis,
                       tstyle='linear', subset=None):
        """\
        Move the specified target object through the plane of the specified
        laser, generate profile relevance models by projection, and return the
        overall coverage and relevance models in the original target pose. The
        target motion is based on the original pose and may be linear or rotary.

        @param laser: The laser line generator to use.
        @type laser: L{LineLaser}
        @param target: The target object.
        @type target: L{SceneObject}
        @param lpitch: The horizontal laser projection pitch in distance units.
        @type lpitch: C{float}
        @param tpitch: The transport pitch in distance units or radians.
        @type tpitch: C{float} or L{Angle}
        @param taxis: The transport axis and (rotary only) target center point.
        @type taxis: L{Point} or C{tuple} of L{Point}
        @param tstyle: The transport style (linear or rotary).
        @type tstyle: C{str}
        @param subset: Subset of cameras (defaults to all active cameras).
        @type subset: C{set}
        @return: The coverage and relevance models.
        @rtype: L{PointCache}, L{RelevanceModel}
        """
        coverage, relevance_original = PointCache(), PointCache()
        original_pose = target.pose
        if tstyle == 'linear':
            # find least and greatest triangle vertices along taxis
            taxis = taxis.normal
            lv, gv = float('inf'), -float('inf')
            for triangle in target.triangles:
                for vertex in triangle.mapped_triangle.vertices:
                    pv = taxis * vertex
                    lv = min(lv, pv)
                    gv = max(gv, pv)
            steps = int((gv - lv) / float(tpitch))
            for i in range(steps):
                # get coverage of profile
                target.set_absolute_pose(original_pose + \
                    Pose(T=((tpitch * i - gv) * taxis)))
                prof_relevance = laser.project(target, lpitch)
                prof_coverage = self.coverage(prof_relevance, subset=subset)
                # add to main coverage result
                for point in prof_coverage:
                    original_point = (-target.pose + original_pose).map(point)
                    coverage[original_point] = prof_coverage[point]
                    relevance_original[original_point] = 1.0
        elif tstyle == 'rotary':
            #steps = int(2 * pi / float(tpitch))
            # TODO: the rest...
            raise ValueError('rotary transport style not yet implemented')
        else:
            raise ValueError('transport style must be \'linear\' or \'rotary\'')
        target.set_absolute_pose(original_pose)
        # TODO: for each point in coverage, scale by laser coverage
        relevance = RelevanceModel(relevance_original)
        return coverage, relevance
