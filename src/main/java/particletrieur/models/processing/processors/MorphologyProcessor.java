package particletrieur.models.processing.processors;

import particletrieur.models.processing.Mask;
import particletrieur.models.processing.Morphology;
import particletrieur.models.processing.ParticleImage;
import org.opencv.core.*;
import org.opencv.imgproc.Imgproc;
import org.opencv.imgproc.Moments;

import java.util.ArrayList;

public class MorphologyProcessor {

    public static Morphology calculateMorphology(ParticleImage image) {

        Morphology m = new Morphology();

        Mask mask = image.mask;
        Mat greyscale;
//        if (image.workingImage.channels() == 3) {
//            greyscale = new Mat();
//            Imgproc.cvtColor(image.workingImage, greyscale, Imgproc.COLOR_BGR2GRAY);
//        }
//        else {
            greyscale = image.greyscaleImage.clone();
//        }
        Mat binary = mask.binary;
        Mat binaryF = mask.binaryF;
        MatOfPoint contour = mask.contour;
        MatOfPoint2f contour2f = mask.contour2f;

        //Exit if mask is non-existant or too small
        if (contour == null) {
            image.morphology = m;
            return null;
        }
        m.area = Imgproc.contourArea(contour);
        if (m.area < 25) {
            image.morphology = m;
            return null;
        }

        m.width = image.workingImage.width();
        m.height = image.workingImage.height();

        m.meanDiameter = Math.sqrt(m.area / Math.PI) * 2;

        //
        // IMAGE INTENSITY MOMENTS
        //
        //Mean(0) and standard deviation(1)
        MatOfDouble meanMat = new MatOfDouble();
        MatOfDouble stddevMat = new MatOfDouble();
        Core.meanStdDev(greyscale, meanMat, stddevMat, binary);
        m.mean = meanMat.get(0, 0)[0];
        m.stddev = stddevMat.get(0, 0)[0];
        m.stddevInvariant = m.stddev / m.mean;
        meanMat.release();
        stddevMat.release();

        double variance = Math.pow(m.stddev,2);
        double numPixelsInMask = Core.sumElems(binaryF).val[0];

        Mat greyscaleMasked = new Mat();

        //Mean
        Core.multiply(binaryF, greyscale, greyscaleMasked, 1.0, CvType.CV_32FC1);
        m.mean = Core.sumElems(greyscaleMasked).val[0] / numPixelsInMask;

        //Subtract mean
        Core.subtract(greyscaleMasked, new Scalar(m.mean), greyscaleMasked);
        Core.multiply(greyscaleMasked, binaryF, greyscaleMasked, 1.0, CvType.CV_32FC1);

        //Standard deviation
        Mat temp = new Mat();
        Core.pow(greyscaleMasked, 2, temp);
        double tempSum = Core.sumElems(temp).val[0];
        m.stddev = Math.sqrt(tempSum / numPixelsInMask);

        //Skew
        Core.pow(greyscaleMasked, 3, temp);
        tempSum = Core.sumElems(temp).val[0];
        m.skew = tempSum / Math.pow(m.stddev, 3) / numPixelsInMask;

        //Kurtosis
        Core.pow(greyscaleMasked, 4, temp);
        tempSum = Core.sumElems(temp).val[0];
        m.kurtosis = tempSum / Math.pow(m.stddev, 4) / numPixelsInMask;

        //5th moment
        Core.pow(greyscaleMasked, 5, temp);
        tempSum = Core.sumElems(temp).val[0];
        m.moment5 = tempSum / Math.pow(m.stddev, 5) / numPixelsInMask;

        //6th moment
        Core.pow(greyscaleMasked, 6, temp);
        tempSum = Core.sumElems(temp).val[0];
        m.moment6 = tempSum / Math.pow(m.stddev, 6) / numPixelsInMask;

        temp.release();
        greyscaleMasked.release();


        //
        // MASK DIMENSIONS
        //
        //Area and perimeter
        m.perimeter = Imgproc.arcLength(contour2f, true);

        //Convex area and perimeter
        MatOfInt hull = new MatOfInt();
        Imgproc.convexHull(contour, hull);
        Point[] temp1 = contour.toArray();
        int[] temp2 = hull.toArray();
        ArrayList<Point> tempPoints = new ArrayList<>();
        for (int tempIdx : temp2) {
            tempPoints.add(temp1[tempIdx]);
        }
        MatOfPoint convexContour = new MatOfPoint(tempPoints.toArray(new Point[tempPoints.size()]));

        m.convexArea = Imgproc.contourArea(convexContour);
        m.convexPerimeter = Imgproc.arcLength(new MatOfPoint2f(convexContour.toArray()), true);
        m.convexPerimeterToPerimeterRatio = m.convexPerimeter / m.perimeter;
        m.convexAreaToAreaRatio = m.convexArea / m.area;

        hull.release();
        convexContour.release();

        //
        // ELLIPSE AND CIRCLE
        //
        //Enclosing circle
        Point centre = new Point();
        float[] radius = new float[1];
        Imgproc.minEnclosingCircle(contour2f, centre, radius);
        m.circleRadius = radius[0];
        m.circleArea = radius[0] * radius[0] * Math.PI;

        //Approximating ellipse
        if(contour2f.rows() >= 5) {
            RotatedRect ellipseRect = Imgproc.fitEllipse(contour2f);
            m.majorAxisLength = ellipseRect.size.height;
            m.minorAxisLength = ellipseRect.size.width;
            m.eccentricity = Math.sqrt(1 - Math.pow(m.minorAxisLength, 2) / Math.pow(m.majorAxisLength, 2));
            m.angle = ellipseRect.angle;
            m.roundness = 4.0 * m.area / Math.PI / Math.pow(m.majorAxisLength,2);
            m.elongation = m.majorAxisLength / m.minorAxisLength;
        }

        //
        // COMMON MEASUREMENTS
        //
        m.solidity = m.area / m.convexArea;
        m.circularity = 4.0 * Math.PI * m.area / Math.pow(m.perimeter, 2);
        m.perimeterToAreaRatio = m.perimeter / m.area;
        m.equivalentDiameter = Math.sqrt(4.0 * m.area / Math.PI);
//        m.equivalentSphericalDiameter = 2.0 * Math.sqrt(m.area / Math.PI);

        Rect boundingRectangle = Imgproc.boundingRect(contour);
        m.aspectRatio = (double)boundingRectangle.width / boundingRectangle.height;
        m.areaToBoundingRectangleArea = m.area / (boundingRectangle.width * boundingRectangle.height);

        double[] dHuInvariants = computeHuInvariantMoments(contour);
        m.Husmoment1 = dHuInvariants[0];
        m.Husmoment2 = dHuInvariants[1];
        m.Husmoment3 = dHuInvariants[2];
        m.Husmoment4 = dHuInvariants[3];
        m.Husmoment5 = dHuInvariants[4];
        m.Husmoment6 = dHuInvariants[5];
        m.Husmoment7 = dHuInvariants[6];


        double[] FeretDiameters = computeFeretDiameters(contour);
        m.MaxFeret = FeretDiameters[0];
        m.MinFeret = FeretDiameters[1];

        return m;
    }

//    private static double[] computeHuInvariants(MatOfPoint contour){
//        Moments p = Imgproc.moments(contour);
//        double
//                n20 = p.get_nu20(),
//                n02 = p.get_nu02(),
//                n30 = p.get_nu30(),
//                n12 = p.get_nu12(),
//                n21 = p.get_nu21(),
//                n03 = p.get_nu03(),
//                n11 = p.get_nu11();
//
//        double[] dHuInvariants = new double[8];
//
//        //First moment
//        dHuInvariants[0] = n20 + n02;
//
//        //Second moment
//        dHuInvariants[1] = Math.pow((n20 - n02), 2) + Math.pow(2 * n11, 2);
//
//        //Third moment
//        dHuInvariants[2] = Math.pow(n30 - (3 * (n12)), 2)
//                + Math.pow((3 * n21 - n03), 2);
//
//        //Fourth moment
//        dHuInvariants[3] = Math.pow((n30 + n12), 2) + Math.pow((n12 + n03), 2);
//
//        //Fifth moment
//        dHuInvariants[4] = (n30 - 3 * n12) * (n30 + n12)
//                * (Math.pow((n30 + n12), 2) - 3 * Math.pow((n21 + n03), 2))
//                + (3 * n21 - n03) * (n21 + n03)
//                * (3 * Math.pow((n30 + n12), 2) - Math.pow((n21 + n03), 2));
//
//        //Sixth moment
//        dHuInvariants[5] = (n20 - n02)
//                * (Math.pow((n30 + n12), 2) - Math.pow((n21 + n03), 2))
//                + 4 * n11 * (n30 + n12) * (n21 + n03);
//
//        //Seventh moment
//        dHuInvariants[6] = (3 * n21 - n03) * (n30 + n12)
//                * (Math.pow((n30 + n12), 2) - 3 * Math.pow((n21 + n03), 2))
//                + (n30 - 3 * n12) * (n21 + n03)
//                * (3 * Math.pow((n30 + n12), 2) - Math.pow((n21 + n03), 2));
//
//        //Eighth moment
//        dHuInvariants[7] = n11 * (Math.pow((n30 + n12), 2) - Math.pow((n03 + n21), 2))
//                - (n20 - n02) * (n30 + n12) * (n03 + n21);
//
//        return dHuInvariants;
//
//    }

    /**
     * Compute Hu's invariant moments from a contour
     * Hu moments are shape descriptors that are invariant to scale, translation, and rotation.
     * @param contour The input contour
     * @return HuMoments An array of 7 standard Hu's invariant moments
     */
    private static double[] computeHuInvariantMoments(MatOfPoint contour) {
        if (contour == null || contour.empty()) {
            throw new IllegalArgumentException("Contour cannot be null or empty");
        }

        // Calculate moments
        Moments p = Imgproc.moments(contour);

        // Extract normalized central moments
        double n20 = p.get_nu20();
        double n02 = p.get_nu02();
        double n30 = p.get_nu30();
        double n12 = p.get_nu12();
        double n21 = p.get_nu21();
        double n03 = p.get_nu03();
        double n11 = p.get_nu11();

        // Pre-compute
        double n30_plus_n12 = n30 + n12;
        double n21_plus_n03 = n21 + n03;
        double sqr_n30_plus_n12 = Math.pow(n30_plus_n12, 2);
        double sqr_n21_plus_n03 = Math.pow(n21_plus_n03, 2);

        double n30_minus_3n12 = n30 - 3 * n12;
        double n3n21_minus_n03 = 3 * n21 - n03;

        // Initialize array for Hu moments
        double[] HuMoments = new double[7];

        // First moment: I₁ = η₂₀ + η₀₂
        HuMoments[0] = n20 + n02;

        // Second moment: I₂ = (η₂₀ - η₀₂)² + 4η₁₁²
        HuMoments[1] = Math.pow(n20 - n02, 2) + 4 * Math.pow(n11, 2);

        // Third moment: I₃ = (η₃₀ - 3η₁₂)² + (3η₂₁ - η₀₃)²
        HuMoments[2] = Math.pow(n30_minus_3n12, 2) + Math.pow(n3n21_minus_n03, 2);

        // Fourth moment: I₄ = (η₃₀ + η₁₂)² + (η₂₁ + η₀₃)²
        HuMoments[3] = sqr_n30_plus_n12 + sqr_n21_plus_n03;

        // Fifth moment: I₅ = (η₃₀ - 3η₁₂)(η₃₀ + η₁₂)[(η₃₀ + η₁₂)² - 3(η₂₁ + η₀₃)²] + (3η₂₁ - η₀₃)(η₂₁ + η₀₃)[3(η₃₀ + η₁₂)² - (η₂₁ + η₀₃)²]
        HuMoments[4] = n30_minus_3n12 * n30_plus_n12 * (sqr_n30_plus_n12 - 3 * sqr_n21_plus_n03) +
                n3n21_minus_n03 * n21_plus_n03 * (3 * sqr_n30_plus_n12 - sqr_n21_plus_n03);

        // Sixth moment: I₆ = (η₂₀ - η₀₂)[(η₃₀ + η₁₂)² - (η₂₁ + η₀₃)²] + 4η₁₁(η₃₀ + η₁₂)(η₂₁ + η₀₃)
        HuMoments[5] = (n20 - n02) * (sqr_n30_plus_n12 - sqr_n21_plus_n03) +
                4 * n11 * n30_plus_n12 * n21_plus_n03;

        // Seventh moment: I₇ = (3η₂₁ - η₀₃)(η₃₀ + η₁₂)[(η₃₀ + η₁₂)² - 3(η₂₁ + η₀₃)²] - (η₃₀ - 3η₁₂)(η₂₁ + η₀₃)[3(η₃₀ + η₁₂)² - (η₂₁ + η₀₃)²]
        HuMoments[6] = n3n21_minus_n03 * n30_plus_n12 * (sqr_n30_plus_n12 - 3 * sqr_n21_plus_n03) -
                n30_minus_3n12 * n21_plus_n03 * (3 * sqr_n30_plus_n12 - sqr_n21_plus_n03);

        // Optional: Apply logarithmic scaling to make values more comparable
        // Uncomment if needed
        /*
        for (int i = 0; i < huMoments.length; i++) {
            if (huMoments[i] != 0) {
                huMoments[i] = -Math.copySign(Math.log10(Math.abs(huMoments[i])), huMoments[i]);
            }
        }
        */

        return HuMoments;
    }


    /**
     * Compute Feret Diameters using Convex Hull method
     * @param contour the input contour
     * @return An array of maximum and minimum Feret diameters
     */
    public static double[] computeFeretDiameters(MatOfPoint contour){
        if (contour == null || contour.empty()) {
            throw new IllegalArgumentException("Contour cannot be null or empty");
        }

        // Create convex hull indices of the contour
        MatOfInt hullIndices = new MatOfInt();
        Imgproc.convexHull(contour, hullIndices);

        Point[] contourPoints = contour.toArray();
        int[] indices = hullIndices.toArray();
        Point[] hullPoints = new Point[indices.length];
        for (int i = 0; i < indices.length; i++) {
            hullPoints[i] = contourPoints[indices[i]];
        }

        if (hullPoints.length < 2) {
            return new double[] {0.0, 0.0};
        }

        // Find the maximum Feret diameter and its angle
        double maxDiameter = 0.0;
        Point maxPoint1 = null;
        Point maxPoint2 = null;

        for (int i = 0; i < hullPoints.length; i++) {
            for (int j = i + 1; j < hullPoints.length; j++) {
                double dx = hullPoints[j].x - hullPoints[i].x;
                double dy = hullPoints[j].y - hullPoints[i].y;
                double distance = Math.sqrt(dx * dx + dy * dy);

                if (distance > maxDiameter) {
                    maxDiameter = distance;
                    maxPoint1 = hullPoints[i];
                    maxPoint2 = hullPoints[j];
                }
            }
        }

        double maxDiameterDx = maxPoint2.x - maxPoint1.x;
        double maxDiameterDy = maxPoint2.y - maxPoint1.y;

        double length = Math.sqrt(maxDiameterDx * maxDiameterDx + maxDiameterDy * maxDiameterDy);
        if (length < 1e-10) {
            return new double[] {0.0, 0.0};
        }

        // Create a perpendicular unit vector (rotate 90 degrees)
        double perpendicularDx = -maxDiameterDy / length;
        double perpendicularDy = maxDiameterDx / length;

        // Find the minimum Feret diameter using the perpendicular direction
        double minDiameter = Double.MAX_VALUE;

        for (int i = 0; i < hullPoints.length; i++) {
            // Project all points onto the perpendicular direction
            double minProj = Double.MAX_VALUE;
            double maxProj = Double.MIN_VALUE;

            for (int j = 0; j < hullPoints.length; j++) {
                // Calculate the projection of point j onto the perpendicular vector
                double proj = perpendicularDx * hullPoints[j].x + perpendicularDy * hullPoints[j].y;
                minProj = Math.min(minProj, proj);
                maxProj = Math.max(maxProj, proj);
            }

            // The width in this direction is the difference between max and min projections
            double width = maxProj - minProj;
            minDiameter = Math.min(minDiameter, width);
        }

        return new double[] {maxDiameter, minDiameter};
    }

}
