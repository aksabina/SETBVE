

public class Normalizer {

    public static double[] minMaxScale(double[] vec) {
        double min = vec[0];
        double max = vec[0];
        for (int i = 1; i < vec.length; i++) {
            if (vec[i] < min) min = vec[i];
            if (vec[i] > max) max = vec[i];
        }
        double[] result = new double[vec.length];
        for (int i = 0; i < vec.length; i++) {
            result[i] = (vec[i] - min) / (max - min);
        }
        return result;
    }


    public static void main(String[] args) {
        double[] input;
        try {
            // Join args and split by space
            String joined = String.join(" ", args);
            String[] parts = joined.trim().split("\\s+");

            if (parts.length == 0 || (parts.length == 1 && parts[0].isEmpty())) {
                input = new double[0];  // empty array
            } else {
                input = new double[parts.length];  // just assign, don't redeclare
                for (int i = 0; i < parts.length; i++) {
                    input[i] = Double.parseDouble(parts[i]);
                }
            }

            double[] output = minMaxScale(input);
            for (double val : output) {
                System.out.print(val + " ");
            }

        } catch (Exception e) {
            System.out.println("Error: " + e.getMessage());
        }
    }
}